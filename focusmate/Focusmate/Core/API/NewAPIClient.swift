import Foundation

final class NewAPIClient {
    private let base: URL
    private let session: URLSession
    private let auth: AuthSession

    init(base: URL = API.base, auth: AuthSession, session: URLSession = .shared) {
        self.base = base
        self.auth = auth
        self.session = session
    }

    func request<T: Decodable>(
        _ method: String, 
        _ path: String,
        query: [URLQueryItem]? = nil,
        body: Encodable? = nil,
        authRequired: Bool = true,
        idempotencyKey: String? = nil
    ) async throws -> T {
        var comps = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        comps.queryItems = query
        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if authRequired {
            let token = try await auth.access()
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let key = idempotencyKey {
            req.setValue(key, forHTTPHeaderField: "Idempotency-Key")
        }

        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw AppError.server("No response") }
            switch http.statusCode {
            case 200...299:
                if T.self == Empty.self { return Empty() as! T }
                return try JSONDecoder().decode(T.self, from: data)
            case 401: throw AppError.unauthenticated
            case 403: throw AppError.forbidden
            case 404: throw AppError.notFound
            case 422:
                let e = try? JSONDecoder().decode(ServerError.self, from: data)
                throw AppError.validation(e?.details ?? [:])
            case 429:
                throw AppError.rateLimited(retryAfter: nil)
            default:
                let e = try? JSONDecoder().decode(ServerError.self, from: data)
                throw AppError.server(e?.message ?? "Server error")
            }
        } catch let e as URLError {
            throw AppError.network(e)
        }
    }

    private struct ServerError: Decodable { 
        let code: String?
        let message: String
        let details: [String:[String]]?
    }
}
