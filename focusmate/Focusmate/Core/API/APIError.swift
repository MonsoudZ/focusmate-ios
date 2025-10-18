import Foundation

enum APIError: Error {
    case badURL
    case badStatus(Int, String?, [String: Any]?)
    case decoding
    case unauthorized
    case network(Error)
    case rateLimited(Int) // 429 with retry-after seconds
    case serverError(Int, String?, [String: Any]?)
    case validation([String: [String]])
    case timeout
    case noInternetConnection
}

// MARK: - Structured Error Response
struct ErrorResponse: Codable {
    let code: String
    let message: String
    let details: [String: Any]?
    let timestamp: String?
    let requestId: String?
    
    enum CodingKeys: String, CodingKey {
        case code, message, details, timestamp
        case requestId = "request_id"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(String.self, forKey: .code)
        message = try container.decode(String.self, forKey: .message)
        details = try container.decodeIfPresent([String: Any].self, forKey: .details)
        timestamp = try container.decodeIfPresent(String.self, forKey: .timestamp)
        requestId = try container.decodeIfPresent(String.self, forKey: .requestId)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(code, forKey: .code)
        try container.encode(message, forKey: .message)
        try container.encodeIfPresent(details, forKey: .details)
        try container.encodeIfPresent(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(requestId, forKey: .requestId)
    }
}


