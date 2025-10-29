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
  let details: [String: String]?
  let timestamp: String?
  let requestId: String?

  enum CodingKeys: String, CodingKey {
    case code, message, details, timestamp
    case requestId = "request_id"
  }

  init(
    code: String,
    message: String,
    details: [String: String]? = nil,
    timestamp: String? = nil,
    requestId: String? = nil
  ) {
    self.code = code
    self.message = message
    self.details = details
    self.timestamp = timestamp
    self.requestId = requestId
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.code = try container.decode(String.self, forKey: .code)
    self.message = try container.decode(String.self, forKey: .message)
    self.details = try container.decodeIfPresent([String: String].self, forKey: .details)
    self.timestamp = try container.decodeIfPresent(String.self, forKey: .timestamp)
    self.requestId = try container.decodeIfPresent(String.self, forKey: .requestId)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.code, forKey: .code)
    try container.encode(self.message, forKey: .message)
    try container.encodeIfPresent(self.details, forKey: .details)
    try container.encodeIfPresent(self.timestamp, forKey: .timestamp)
    try container.encodeIfPresent(self.requestId, forKey: .requestId)
  }
}
