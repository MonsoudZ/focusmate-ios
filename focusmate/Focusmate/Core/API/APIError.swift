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
  let code: String?
  let message: String?
  let details: [String: [String]]?  // For validation errors
  let timestamp: String?
  let status: Int?
  let requestId: String?

  // Support both formats: direct and nested
  let error: NestedError?

  struct NestedError: Codable {
    let message: String
    let status: Int?
    let timestamp: String?
  }

  var errorMessage: String {
    error?.message ?? message ?? "Unknown error"
  }

  enum CodingKeys: String, CodingKey {
    case code, message, details, timestamp, status
    case requestId = "request_id"
    case error
  }

  init(
    code: String? = nil,
    message: String? = nil,
    details: [String: [String]]? = nil,
    timestamp: String? = nil,
    status: Int? = nil,
    requestId: String? = nil,
    error: NestedError? = nil
  ) {
    self.code = code
    self.message = message
    self.details = details
    self.timestamp = timestamp
    self.status = status
    self.requestId = requestId
    self.error = error
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.code = try container.decodeIfPresent(String.self, forKey: .code)
    self.message = try container.decodeIfPresent(String.self, forKey: .message)
    self.details = try container.decodeIfPresent([String: [String]].self, forKey: .details)
    self.timestamp = try container.decodeIfPresent(String.self, forKey: .timestamp)
    self.status = try container.decodeIfPresent(Int.self, forKey: .status)
    self.requestId = try container.decodeIfPresent(String.self, forKey: .requestId)
    self.error = try container.decodeIfPresent(NestedError.self, forKey: .error)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(self.code, forKey: .code)
    try container.encodeIfPresent(self.message, forKey: .message)
    try container.encodeIfPresent(self.details, forKey: .details)
    try container.encodeIfPresent(self.timestamp, forKey: .timestamp)
    try container.encodeIfPresent(self.status, forKey: .status)
    try container.encodeIfPresent(self.requestId, forKey: .requestId)
    try container.encodeIfPresent(self.error, forKey: .error)
  }
}
