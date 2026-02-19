import Foundation

protocol NetworkingProtocol {
  func request<T: Decodable>(
    _ method: String,
    _ path: String,
    body: (some Encodable)?,
    queryParameters: [String: String],
    idempotencyKey: String?
  ) async throws -> T

  func getRawResponse(endpoint: String, params: [String: String]) async throws -> Data
}

// MARK: - Token Refresh Coordinator

/// Ensures only one token refresh runs at a time. Concurrent 401 handlers
/// wait for the in-progress refresh rather than starting duplicate requests.
private actor TokenRefreshCoordinator {
  private var refreshTask: Task<Void, Error>?

  func refreshIfNeeded(using refresher: @escaping () async throws -> Void) async throws {
    if let existing = refreshTask {
      try await existing.value
      return
    }

    let task = Task { try await refresher() }
    self.refreshTask = task

    do {
      try await task.value
      self.refreshTask = nil
    } catch {
      self.refreshTask = nil
      throw error
    }
  }
}

final class InternalNetworking: NetworkingProtocol {
  private let tokenProvider: () -> String?
  private let refreshTokenProvider: (() -> String?)?
  private let onTokenRefreshed: ((String, String?) async -> Void)?
  private let sentryService = SentryService.shared
  private let certificatePinning: CertificatePinning
  private let refreshCoordinator = TokenRefreshCoordinator()

  /// Optional injected session for tests/previews/custom configs.
  private let injectedSession: URLSession?

  private lazy var session: URLSession = {
    if let injectedSession { return injectedSession }

    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = AppConfiguration.Network.requestTimeoutSeconds
    configuration.timeoutIntervalForResource = AppConfiguration.Network.resourceTimeoutSeconds

    // CertificatePinning is the delegate — NOT self.
    // URLSession retains its delegate strongly.  If we passed `self`,
    // the reference graph would be:
    //   InternalNetworking → session → InternalNetworking  (cycle)
    // By using certificatePinning (which already conforms to
    // URLSessionDelegate), we get:
    //   InternalNetworking → session → CertificatePinning  (no cycle)
    return URLSession(configuration: configuration, delegate: self.certificatePinning, delegateQueue: nil)
  }()

  // MARK: - Initializers

  /// Production initializer (pinning always active)
  init(
    tokenProvider: @escaping () -> String?,
    refreshTokenProvider: (() -> String?)? = nil,
    onTokenRefreshed: ((String, String?) async -> Void)? = nil
  ) {
    self.tokenProvider = tokenProvider
    self.refreshTokenProvider = refreshTokenProvider
    self.onTokenRefreshed = onTokenRefreshed
    self.certificatePinning = CertificatePinningConfig.createPinning()
    self.injectedSession = nil
  }

  /// DI initializer (tests/previews/custom session)
  init(
    tokenProvider: @escaping () -> String?,
    session: URLSession,
    certificatePinning: CertificatePinning = CertificatePinningConfig.createPinning()
  ) {
    self.tokenProvider = tokenProvider
    self.refreshTokenProvider = nil
    self.onTokenRefreshed = nil
    self.injectedSession = session
    self.certificatePinning = certificatePinning
  }

  // MARK: - Requests (public)

  func request<T: Decodable>(
    _ method: String,
    _ path: String,
    body: (some Encodable)? = nil,
    queryParameters: [String: String] = [:],
    idempotencyKey: String? = nil
  ) async throws -> T {
    try await self.performRequest(
      method,
      path,
      body: body,
      queryParameters: queryParameters,
      idempotencyKey: idempotencyKey,
      attemptRefresh: true
    )
  }

  func getRawResponse(endpoint: String, params: [String: String] = [:]) async throws -> Data {
    try await self.performGetRawResponse(endpoint: endpoint, params: params, attemptRefresh: true)
  }

  // MARK: - Requests (private, with retry)

  private func performRequest<T: Decodable>(
    _ method: String,
    _ path: String,
    body: (some Encodable)?,
    queryParameters: [String: String],
    idempotencyKey: String?,
    attemptRefresh: Bool
  ) async throws -> T {
    let url = self.buildURL(path: path, queryParameters: queryParameters)

    var req = URLRequest(url: url)
    req.httpMethod = method

    if let b = body {
      req.httpBody = try APIClient.encoder.encode(b)
      req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    req.setValue("application/json", forHTTPHeaderField: "Accept")

    let isPublicEndpoint = await applyAuth(to: &req, path: path, attemptRefresh: attemptRefresh)

    if let idempotencyKey {
      req.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
    }

    let (data, http) = try await executeRequest(req)

    await self.sentryService.addAPIBreadcrumb(method: method, endpoint: path, statusCode: http.statusCode)

    let errorResponse = self.parseErrorResponse(data: data, statusCode: http.statusCode)

    if let requestId = errorResponse?.requestId, !requestId.isEmpty {
      await RequestContext.shared.setLatestRequestId(requestId)
    }

    switch http.statusCode {
    case 200 ... 299:
      break

    case 401:
      if let retryResult: T = await attemptRefreshAndRetry(
        method: method, path: path,
        isPublicEndpoint: isPublicEndpoint,
        attemptRefresh: attemptRefresh,
        retry: { try await self.performRequest(
          method,
          path,
          body: body,
          queryParameters: queryParameters,
          idempotencyKey: idempotencyKey,
          attemptRefresh: false
        ) }
      ) {
        return retryResult
      }
      Logger.warning("401 Unauthorized for \(method) \(path)", category: .api)
      if !isPublicEndpoint {
        AuthEventBus.shared.send(.unauthorized)
      }
      throw APIError.unauthorized(errorResponse?.errorMessage)

    case 422:
      Logger.warning("422 Validation error for \(method) \(path)", category: .api)
      if let details = errorResponse?.validationDetails, !details.isEmpty {
        throw APIError.validation(details)
      }
      throw APIError.badStatus(http.statusCode, errorResponse?.errorMessage, nil)

    case 429:
      let retryAfter = self.extractRetryAfter(from: http.allHeaderFields)
      Logger.warning("429 Rate Limited for \(method) \(path)", category: .api)
      throw APIError.rateLimited(retryAfter)

    case 500 ... 599:
      Logger.error("Server error \(http.statusCode) for \(method) \(path)", category: .api)
      throw APIError.serverError(http.statusCode, errorResponse?.errorMessage, nil)

    default:
      Logger.warning("Bad status \(http.statusCode) for \(method) \(path)", category: .api)
      throw APIError.badStatus(http.statusCode, errorResponse?.errorMessage, nil)
    }

    if data.isEmpty {
      if T.self == EmptyResponse.self, let empty = EmptyResponse() as? T {
        return empty
      }
      throw APIError.decoding
    }

    do {
      return try APIClient.decoder.decode(T.self, from: data)
    } catch let decodingError {
      Logger.error("Decoding failed for \(method) \(path): \(decodingError)", category: .api)

      #if DEBUG
        let raw = String(data: data, encoding: .utf8) ?? "unable to read"
        let redacted = LogRedactor.redact(raw)
        let capped = redacted.count > 4000 ? String(redacted.prefix(4000)) + "…(truncated)" : redacted
        Logger.error("Raw JSON (debug, redacted): \(capped)", category: .api)
      #endif

      throw APIError.decoding
    }
  }

  private func performGetRawResponse(
    endpoint: String,
    params: [String: String],
    attemptRefresh: Bool
  ) async throws -> Data {
    let url = self.buildURL(path: endpoint, queryParameters: params)

    var req = URLRequest(url: url)
    req.httpMethod = "GET"
    req.setValue("application/json", forHTTPHeaderField: "Accept")

    let isPublicEndpoint = await applyAuth(to: &req, path: endpoint, attemptRefresh: attemptRefresh)

    let (data, http) = try await executeRequest(req)

    switch http.statusCode {
    case 200 ... 299:
      return data
    case 401:
      if let retryResult: Data = await attemptRefreshAndRetry(
        method: "GET", path: endpoint,
        isPublicEndpoint: isPublicEndpoint,
        attemptRefresh: attemptRefresh,
        retry: { try await self.performGetRawResponse(endpoint: endpoint, params: params, attemptRefresh: false) }
      ) {
        return retryResult
      }
      if !isPublicEndpoint {
        AuthEventBus.shared.send(.unauthorized)
      }
      throw APIError.unauthorized(nil)
    default:
      throw APIError.badStatus(http.statusCode, nil, nil)
    }
  }

  // MARK: - Shared Request Helpers

  /// Builds a URL from a path, appending query parameters if present.
  private func buildURL(path: String, queryParameters: [String: String]) -> URL {
    var url = API.path(path)
    guard !queryParameters.isEmpty else { return url }

    if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
      components.queryItems = queryParameters.map { URLQueryItem(name: $0.key, value: $0.value) }
      if let newURL = components.url {
        url = newURL
      } else {
        Logger.warning(
          "Failed to construct URL with query parameters for \(path), using URL without params",
          category: .api
        )
      }
    } else {
      Logger.warning("Failed to create URLComponents for \(path), query parameters will be ignored", category: .api)
    }
    return url
  }

  /// Applies the Authorization header and performs proactive token refresh if needed.
  ///
  /// Public endpoints (auth/sign_in, etc.) skip the Authorization header entirely.
  /// For authenticated endpoints, if the JWT expires within the buffer window,
  /// refreshes proactively to eliminate the request → 401 → refresh → retry
  /// double round trip (~200-400ms). Cost: ~5μs to parse the JWT payload.
  ///
  /// Returns whether this is a public endpoint (used by 401 handling downstream).
  private func applyAuth(to request: inout URLRequest, path: String, attemptRefresh: Bool) async -> Bool {
    let publicEndpoints = ["auth/apple", "auth/sign_in", "auth/sign_up", "auth/refresh", "auth/password"]
    let isPublicEndpoint = publicEndpoints.contains { path.hasSuffix($0) }

    guard !isPublicEndpoint, let jwt = tokenProvider() else {
      return isPublicEndpoint
    }

    request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")

    if attemptRefresh, self.refreshTokenProvider != nil, self.onTokenRefreshed != nil,
       JWTExpiry.isExpiringSoon(jwt, buffer: AppConfiguration.Auth.proactiveRefreshBufferSeconds)
    {
      do {
        try await self.attemptTokenRefresh()
        if let freshJwt = tokenProvider() {
          request.setValue("Bearer \(freshJwt)", forHTTPHeaderField: "Authorization")
        }
      } catch {
        // Proactive refresh failed — proceed with current token.
        // The reactive 401 path will catch it if the token is truly expired.
        Logger.debug("Proactive token refresh failed, proceeding with current token", category: .auth)
      }
    }

    return isPublicEndpoint
  }

  /// Sends the request and maps transport-level errors to APIError.
  private func executeRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let data: Data
    let resp: URLResponse

    do {
      (data, resp) = try await self.session.data(for: request)
    } catch {
      throw self.mapNetworkError(error)
    }

    guard let http = resp as? HTTPURLResponse else { throw APIError.badURL }
    return (data, http)
  }

  /// Handles a 401 by attempting token refresh and retrying the request once.
  ///
  /// Returns the retry result on success, or nil if refresh wasn't attempted or
  /// failed (caller should fall through to throw unauthorized).
  /// Emits Sentry breadcrumbs at each stage for debugging auth failures.
  private func attemptRefreshAndRetry<T>(
    method: String,
    path: String,
    isPublicEndpoint: Bool,
    attemptRefresh: Bool,
    retry: () async throws -> T
  ) async -> T? {
    guard !isPublicEndpoint, attemptRefresh,
          self.refreshTokenProvider != nil, self.onTokenRefreshed != nil
    else {
      return nil
    }

    await self.sentryService.addBreadcrumb(
      message: "Token refresh triggered by 401",
      category: "auth",
      level: .warning,
      data: ["endpoint": path, "method": method]
    )

    do {
      try await self.attemptTokenRefresh()
      await self.sentryService.addBreadcrumb(
        message: "Token refresh succeeded, retrying request",
        category: "auth",
        level: .info,
        data: ["endpoint": path, "method": method]
      )
      Logger.info("Token refreshed, retrying \(method) \(path)", category: .api)
      return try await retry()
    } catch {
      await self.sentryService.addBreadcrumb(
        message: "Token refresh failed",
        category: "auth",
        level: .error,
        data: ["endpoint": path, "method": method, "error": String(describing: error)]
      )
      Logger.warning("Token refresh failed for \(method) \(path): \(error)", category: .api)
      return nil
    }
  }

  // MARK: - Token Refresh

  /// Attempts to refresh the access token using the stored refresh token.
  /// Uses the coordinator to ensure only one refresh runs at a time.
  /// Makes the refresh call directly on this instance's pinned URLSession
  /// to maintain certificate pinning without going through the full request chain.
  private func attemptTokenRefresh() async throws {
    try await self.refreshCoordinator.refreshIfNeeded { [self] in
      guard let refreshTokenProvider, let onTokenRefreshed else {
        throw APIError.unauthorized(nil)
      }

      guard let refreshToken = refreshTokenProvider() else {
        // Breadcrumb 4: No refresh token available — explains why refresh couldn't be attempted
        await self.sentryService.addBreadcrumb(
          message: "No refresh token available",
          category: "auth",
          level: .warning
        )
        Logger.warning("No refresh token available", category: .auth)
        throw APIError.unauthorized(nil)
      }

      let url = API.path(API.Auth.refresh)
      var req = URLRequest(url: url)
      req.httpMethod = "POST"
      req.setValue("application/json", forHTTPHeaderField: "Content-Type")
      req.setValue("application/json", forHTTPHeaderField: "Accept")
      req.httpBody = try APIClient.encoder.encode(RefreshTokenRequest(refreshToken: refreshToken))

      let (data, resp) = try await session.data(for: req)

      guard let http = resp as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
        // Breadcrumb 5: Refresh endpoint returned non-2xx — the refresh call itself failed
        let statusCode = (resp as? HTTPURLResponse)?.statusCode
        await self.sentryService.addBreadcrumb(
          message: "Refresh endpoint returned non-2xx",
          category: "auth",
          level: .error,
          data: statusCode.map { ["status_code": $0] }
        )
        Logger.warning("Refresh endpoint returned non-2xx", category: .auth)
        throw APIError.unauthorized(nil)
      }

      let result = try APIClient.decoder.decode(AuthSignInResponse.self, from: data)
      await onTokenRefreshed(result.token, result.refreshToken)
      Logger.info("Token refresh successful", category: .auth)
    }
  }

  // MARK: - Helpers

  private func parseErrorResponse(data: Data, statusCode: Int) -> ErrorResponse? {
    guard !data.isEmpty, statusCode >= 400 else { return nil }

    // Try structured ErrorResponse first
    do {
      return try APIClient.decoder.decode(ErrorResponse.self, from: data)
    } catch {
      Logger.debug("ErrorResponse decode failed, trying fallback: \(error.localizedDescription)", category: .api)
    }

    // Fallback to manual JSON parsing
    guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
      Logger.debug("Failed to parse error response as JSON", category: .api)
      return nil
    }

    if let errorObj = json["error"] as? [String: Any] {
      let details = errorObj["details"] as? [String: [String]]
      return ErrorResponse(
        code: errorObj["code"] as? String ?? "HTTP_\(statusCode)",
        message: errorObj["message"] as? String ?? "HTTP \(statusCode) error",
        details: details,
        timestamp: errorObj["timestamp"] as? String,
        status: statusCode,
        requestId: json["request_id"] as? String
      )
    }

    return ErrorResponse(
      code: json["code"] as? String ?? "HTTP_\(statusCode)",
      message: json["message"] as? String ?? json["error"] as? String ?? "HTTP \(statusCode) error",
      details: json["details"] as? [String: [String]],
      timestamp: json["timestamp"] as? String,
      status: statusCode,
      requestId: json["request_id"] as? String
    )
  }

  private func extractRetryAfter(from headers: [AnyHashable: Any]) -> Int {
    if let retryAfter = headers["Retry-After"] as? String, let seconds = Int(retryAfter) {
      return seconds
    }
    return 60
  }

  private func mapNetworkError(_ error: Error) -> APIError {
    if let urlError = error as? URLError {
      switch urlError.code {
      case .timedOut:
        return .timeout
      case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
        return .noInternetConnection
      default:
        return .network(urlError)
      }
    }
    return .network(error)
  }
}
