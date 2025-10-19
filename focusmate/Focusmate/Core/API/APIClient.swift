import Foundation

final class APIClient {
    private let session: URLSession = .shared
    private let tokenProvider: () -> String?

    init(tokenProvider: @escaping () -> String?) {
        self.tokenProvider = tokenProvider
    }
    
    func getToken() -> String? {
        return tokenProvider()
    }
    
    func getSession() -> URLSession {
        return session
    }
    
    // MARK: - JSON Decoder Configuration
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        
        // No key conversion - property names match JSON keys exactly
        // decoder.keyDecodingStrategy = .convertFromSnakeCase  // REMOVED
        
        // Handle ISO8601 date strings from Rails
        decoder.dateDecodingStrategy = .iso8601
        
        return decoder
    }()
    
    // MARK: - Rails API Decoder (alias for clarity)
    static let railsAPI = decoder

    // MARK: - JSON Encoder Configuration
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        // Match Rails expectations
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    func request<T: Decodable, B: Encodable>(_ method: String, _ path: String, body: B? = nil) async throws -> T {
        let url = Endpoints.path(path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let b = body {
            req.httpBody = try APIClient.encoder.encode(b)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        // Explicitly request JSON
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        // ngrok bypass header to skip browser warning page
        req.setValue("ngrok-skip-browser-warning", forHTTPHeaderField: "ngrok-skip-browser-warning")
        if let jwt = tokenProvider() {
            req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
            print("🔑 APIClient: Using JWT token: \(jwt.prefix(20))...")
        } else {
            print("⚠️ APIClient: No JWT token available")
        }

        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw APIError.badURL }
            
            // Parse error response if present
            let errorResponse = parseErrorResponse(data: data, statusCode: http.statusCode)
            
            switch http.statusCode {
            case 200...299:
                break
            case 401:
                print("🚫 APIClient: 401 Unauthorized for \(method) \(url.absoluteString)")
                throw APIError.unauthorized
            case 429:
                let retryAfter = extractRetryAfter(from: http.allHeaderFields)
                print("⏰ APIClient: 429 Rate Limited for \(method) \(url.absoluteString), retry after: \(retryAfter)s")
                throw APIError.rateLimited(retryAfter)
            case 500...599:
                print("🔥 APIClient: Server error \(http.statusCode) for \(method) \(url.absoluteString)")
                throw APIError.serverError(http.statusCode, errorResponse?.message, errorResponse?.details)
            default:
                let bodyPreview = String(data: data, encoding: .utf8) ?? "<non-utf8>"
                print("⚠️ APIClient: bad status \(http.statusCode) for \(method) \(url.absoluteString) body=\(bodyPreview)")
                throw APIError.badStatus(http.statusCode, errorResponse?.message, errorResponse?.details)
            }
            do { 
                // Handle empty responses (common for DELETE requests)
                if data.isEmpty {
                    // For empty responses, we can't decode to a specific type
                    // This is expected for DELETE requests that return 204 No Content
                    if T.self == EmptyResponse.self {
                        return EmptyResponse() as! T
                    } else {
                        // If we're expecting a specific type but got empty data, that's an error
                        print("🧩 APIClient: Expected \(T.self) but got empty response")
                        throw APIError.decoding
                    }
                }
                
                let result = try APIClient.railsAPI.decode(T.self, from: data)
                // Debug completion responses
                if url.absoluteString.contains("/complete") {
                    let bodyPreview = String(data: data, encoding: .utf8) ?? "<non-utf8>"
                    print("🔍 APIClient: Completion response body: \(bodyPreview)")
                }
                return result
            }
            catch {
                let bodyPreview = String(data: data, encoding: .utf8) ?? "<non-utf8>"
                print("🧩 APIClient: decoding error for \(method) \(url.absoluteString)")
                print("🧩 APIClient: Response body: \(bodyPreview)")
                print("🧩 APIClient: Decoding error: \(error)")
                throw APIError.decoding
            }
        } catch {
            if let apiError = error as? APIError { throw apiError }
            throw APIError.network(error)
        }
    }
    
    // MARK: - Error Response Parsing
    
    private func parseErrorResponse(data: Data, statusCode: Int) -> ErrorResponse? {
        guard !data.isEmpty, statusCode >= 400 else { return nil }
        
        do {
            let errorResponse = try APIClient.railsAPI.decode(ErrorResponse.self, from: data)
            return errorResponse
        } catch {
            // If we can't parse as structured error, try to extract basic info
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let message = json["message"] as? String ?? json["error"] as? String
                let code = json["code"] as? String ?? "HTTP_\(statusCode)"
                
                // Convert [String: Any] to [String: String]
                let stringDetails = json.compactMapValues { value in
                    if let stringValue = value as? String {
                        return stringValue
                    } else if let numberValue = value as? NSNumber {
                        return numberValue.stringValue
                    } else {
                        return String(describing: value)
                    }
                }
                
                return ErrorResponse(
                    code: code,
                    message: message ?? "HTTP \(statusCode) error",
                    details: stringDetails.isEmpty ? nil : stringDetails,
                    timestamp: nil,
                    requestId: nil
                )
            }
            return nil
        }
    }
    
    private func extractRetryAfter(from headers: [AnyHashable: Any]) -> Int {
        if let retryAfter = headers["Retry-After"] as? String,
           let seconds = Int(retryAfter) {
            return seconds
        }
        return 60 // Default retry after 60 seconds
    }
}


