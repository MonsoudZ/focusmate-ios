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

final class InternalNetworking: NSObject, NetworkingProtocol {
    private var session: URLSession!
    private let tokenProvider: () -> String?
    private let sentryService = SentryService.shared
    private let certificatePinning: CertificatePinning

    init(tokenProvider: @escaping () -> String?) {
        self.tokenProvider = tokenProvider
        self.certificatePinning = CertificatePinningConfig.createPinning()

        super.init()

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60

        self.session = URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: nil
        )

        #if DEBUG
        Logger.debug("Certificate pinning initialized", category: .api)
        #endif
    }

    func request<T: Decodable>(
        _ method: String,
        _ path: String,
        body: (some Encodable)? = nil,
        queryParameters: [String: String] = [:],
        idempotencyKey: String? = nil
    ) async throws -> T {
        var url = API.path(path)

        if !queryParameters.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = queryParameters.map { URLQueryItem(name: $0.key, value: $0.value) }
            if let newURL = components?.url {
                url = newURL
            }
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        if let b = body {
            req.httpBody = try APIClient.encoder.encode(b)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        if let jwt = tokenProvider() {
            req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        }

        if let idempotencyKey = idempotencyKey {
            req.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.badURL }

        sentryService.addAPIBreadcrumb(method: method, endpoint: path, statusCode: http.statusCode)

        let errorResponse = parseErrorResponse(data: data, statusCode: http.statusCode)

        switch http.statusCode {
        case 200...299:
            break
        case 401:
            Logger.warning("401 Unauthorized for \(method) \(path)", category: .api)
            throw APIError.unauthorized
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
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            throw APIError.decoding
        }

        do {
            return try APIClient.decoder.decode(T.self, from: data)
        } catch {
            Logger.error("Decoding error for \(method) \(path)", error: error, category: .api)
            throw APIError.decoding
        }
    }

    func getRawResponse(endpoint: String, params: [String: String] = [:]) async throws -> Data {
        var url = API.path(endpoint)

        if !params.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
            if let newURL = components?.url {
                url = newURL
            }
        }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        if let jwt = tokenProvider() {
            req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        }

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.badURL }

        switch http.statusCode {
        case 200...299:
            return data
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.badStatus(http.statusCode, nil, nil)
        }
    }

    private func parseErrorResponse(data: Data, statusCode: Int) -> ErrorResponse? {
        guard !data.isEmpty, statusCode >= 400 else { return nil }
        
        // Try to decode as ErrorResponse first
        if let errorResponse = try? APIClient.decoder.decode(ErrorResponse.self, from: data) {
            return errorResponse
        }
        
        // Fallback: try to parse as generic JSON
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Check for nested error object
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
            
            // Root level error
            return ErrorResponse(
                code: json["code"] as? String ?? "HTTP_\(statusCode)",
                message: json["message"] as? String ?? json["error"] as? String ?? "HTTP \(statusCode) error",
                details: json["details"] as? [String: [String]],
                timestamp: json["timestamp"] as? String,
                status: statusCode,
                requestId: json["request_id"] as? String
            )
        }
        return nil
    }

    private func extractRetryAfter(from headers: [AnyHashable: Any]) -> Int {
        if let retryAfter = headers["Retry-After"] as? String, let seconds = Int(retryAfter) {
            return seconds
        }
        return 60
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
