import Foundation

enum APIError: Error {
  case badURL
  case badStatus(Int, String?, [String: Any]?)
  case decoding
  case unauthorized(String?)
  case network(Error)
  case rateLimited(Int)
  case serverError(Int, String?, [String: Any]?)
  case validation([String: [String]])
  case timeout
  case noInternetConnection
}

// MARK: - Structured Error Response

struct ErrorResponse: Codable {
  let code: String?
  let message: String?
  let details: [String: [String]]?
  let timestamp: String?
  let status: Int?
  let requestId: String?
  let error: NestedError?

  struct NestedError: Codable {
    let code: String?
    let message: String?
    let status: Int?
    let timestamp: String?
    let details: [String: [String]]?
  }

  var errorMessage: String {
    error?.message ?? message ?? "Unknown error"
  }
  
  var validationDetails: [String: [String]]? {
    error?.details ?? details
  }
  
  var errorCode: String? {
    error?.code ?? code
  }

  enum CodingKeys: String, CodingKey {
    case code, message, details, timestamp, status, error
    case requestId = "request_id"
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
}
