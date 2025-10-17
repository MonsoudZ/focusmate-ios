import Foundation

final class APIClient {
    private let session: URLSession = .shared
    private let tokenProvider: () -> String?

    init(tokenProvider: @escaping () -> String?) {
        self.tokenProvider = tokenProvider
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
            switch http.statusCode {
            case 200...299:
                break
            case 401:
                print("🚫 APIClient: 401 Unauthorized for \(method) \(url.absoluteString)")
                throw APIError.unauthorized
            default:
                let bodyPreview = String(data: data, encoding: .utf8) ?? "<non-utf8>"
                print("⚠️ APIClient: bad status \(http.statusCode) for \(method) \(url.absoluteString) body=\(bodyPreview)")
                throw APIError.badStatus(http.statusCode)
            }
            do { 
                return try APIClient.railsAPI.decode(T.self, from: data)
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
}


