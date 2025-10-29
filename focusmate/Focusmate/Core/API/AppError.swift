import Foundation

enum AppError: Error {
    case unauthenticated, forbidden, notFound
    case rateLimited(retryAfter: TimeInterval?)
    case validation([String: [String]])
    case server(String)
    case network(URLError)
    case decode(Error)
}
