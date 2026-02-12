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
        refreshTask = task

        do {
            try await task.value
            refreshTask = nil
        } catch {
            refreshTask = nil
            throw error
        }
    }
}

final class InternalNetworking: NSObject, NetworkingProtocol {
    private let tokenProvider: () -> String?
    private let refreshTokenProvider: (() -> String?)?
    private let onTokenRefreshed: ((String, String?) async -> Void)?
    private let sentryService = SentryService.shared
    private let certificatePinning: CertificatePinning
    private let refreshCoordinator = TokenRefreshCoordinator()

    // Optional injected session for tests/previews/custom configs.
    // If you inject a session and still want pinning, that session must use this instance as its delegate.
    private let injectedSession: URLSession?

    private lazy var session: URLSession = {
        if let injectedSession { return injectedSession }

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = AppConfiguration.Network.requestTimeoutSeconds
        configuration.timeoutIntervalForResource = AppConfiguration.Network.resourceTimeoutSeconds

        // Delegate must be self so certificate pinning runs.
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
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
        super.init()
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
        super.init()
    }

    // MARK: - Requests (public)

    func request<T: Decodable>(
        _ method: String,
        _ path: String,
        body: (some Encodable)? = nil,
        queryParameters: [String: String] = [:],
        idempotencyKey: String? = nil
    ) async throws -> T {
        try await performRequest(method, path, body: body, queryParameters: queryParameters, idempotencyKey: idempotencyKey, attemptRefresh: true)
    }

    func getRawResponse(endpoint: String, params: [String: String] = [:]) async throws -> Data {
        try await performGetRawResponse(endpoint: endpoint, params: params, attemptRefresh: true)
    }

    // MARK: - Requests (private, with retry)

    private func performRequest<Body: Encodable, T: Decodable>(
        _ method: String,
        _ path: String,
        body: Body?,
        queryParameters: [String: String],
        idempotencyKey: String?,
        attemptRefresh: Bool
    ) async throws -> T {
        var url = API.path(path)

        if !queryParameters.isEmpty {
            if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                components.queryItems = queryParameters.map { URLQueryItem(name: $0.key, value: $0.value) }
                if let newURL = components.url {
                    url = newURL
                } else {
                    Logger.warning("Failed to construct URL with query parameters for \(path), using URL without params", category: .api)
                }
            } else {
                Logger.warning("Failed to create URLComponents for \(path), query parameters will be ignored", category: .api)
            }
        }

        var req = URLRequest(url: url)
        req.httpMethod = method

        if let b = body {
            req.httpBody = try APIClient.encoder.encode(b)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        req.setValue("application/json", forHTTPHeaderField: "Accept")

        // Public endpoints that don't need auth - skip Authorization header entirely.
        // Uses hasSuffix to avoid false positives (e.g. "auth/password/change" matching "auth/password").
        let publicEndpoints = ["auth/apple", "auth/sign_in", "auth/sign_up", "auth/refresh", "auth/password"]
        let isPublicEndpoint = publicEndpoints.contains { path.hasSuffix($0) }

        if !isPublicEndpoint, let jwt = tokenProvider() {
            req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        }

        if let idempotencyKey {
            req.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }

        let data: Data
        let resp: URLResponse

        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw mapNetworkError(error)
        }

        guard let http = resp as? HTTPURLResponse else { throw APIError.badURL }

        sentryService.addAPIBreadcrumb(method: method, endpoint: path, statusCode: http.statusCode)

        let errorResponse = parseErrorResponse(data: data, statusCode: http.statusCode)

        if let requestId = errorResponse?.requestId, !requestId.isEmpty {
            await RequestContext.shared.setLatestRequestId(requestId)
        }

        switch http.statusCode {
        case 200...299:
            break

        case 401:
            // Don't attempt token refresh for public endpoints - they don't need auth
            if !isPublicEndpoint, attemptRefresh, refreshTokenProvider != nil, onTokenRefreshed != nil {
                do {
                    try await attemptTokenRefresh()
                    Logger.info("Token refreshed, retrying \(method) \(path)", category: .api)
                    return try await performRequest(method, path, body: body, queryParameters: queryParameters, idempotencyKey: idempotencyKey, attemptRefresh: false)
                } catch {
                    Logger.warning("Token refresh failed for \(method) \(path): \(error)", category: .api)
                }
            }
            Logger.warning("401 Unauthorized for \(method) \(path)", category: .api)
            // Don't broadcast unauthorized for public endpoints - they handle their own errors
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
            let retryAfter = extractRetryAfter(from: http.allHeaderFields)
            Logger.warning("429 Rate Limited for \(method) \(path)", category: .api)
            throw APIError.rateLimited(retryAfter)

        case 500...599:
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

    private func performGetRawResponse(endpoint: String, params: [String: String], attemptRefresh: Bool) async throws -> Data {
        var url = API.path(endpoint)

        if !params.isEmpty {
            if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
                if let newURL = components.url {
                    url = newURL
                } else {
                    Logger.warning("Failed to construct URL with params for \(endpoint), using URL without params", category: .api)
                }
            } else {
                Logger.warning("Failed to create URLComponents for \(endpoint), params will be ignored", category: .api)
            }
        }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        if let jwt = tokenProvider() {
            req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let resp: URLResponse

        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw mapNetworkError(error)
        }

        guard let http = resp as? HTTPURLResponse else { throw APIError.badURL }

        switch http.statusCode {
        case 200...299:
            return data
        case 401:
            if attemptRefresh, refreshTokenProvider != nil, onTokenRefreshed != nil {
                do {
                    try await attemptTokenRefresh()
                    Logger.info("Token refreshed, retrying GET \(endpoint)", category: .api)
                    return try await performGetRawResponse(endpoint: endpoint, params: params, attemptRefresh: false)
                } catch {
                    Logger.warning("Token refresh failed for GET \(endpoint): \(error)", category: .api)
                }
            }
            AuthEventBus.shared.send(.unauthorized)
            throw APIError.unauthorized(nil)
        default:
            throw APIError.badStatus(http.statusCode, nil, nil)
        }
    }

    // MARK: - Token Refresh

    /// Attempts to refresh the access token using the stored refresh token.
    /// Uses the coordinator to ensure only one refresh runs at a time.
    /// Makes the refresh call directly on this instance's pinned URLSession
    /// to maintain certificate pinning without going through the full request chain.
    private func attemptTokenRefresh() async throws {
        try await refreshCoordinator.refreshIfNeeded { [self] in
            guard let refreshTokenProvider, let onTokenRefreshed else {
                throw APIError.unauthorized(nil)
            }

            guard let refreshToken = refreshTokenProvider() else {
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

            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
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

// MARK: - URLSessionDelegate (Certificate Pinning)

extension InternalNetworking: URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let host = challenge.protectionSpace.host

        if certificatePinning.validateServerTrust(serverTrust, forDomain: host) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            Logger.error("Certificate validation failed for \(host)", category: .api)
            #if !DEBUG
            SentryService.shared.captureMessage("Certificate pinning failed for: \(host)")
            #endif
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
