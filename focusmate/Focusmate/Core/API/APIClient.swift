import Foundation

final class APIClient {
  private let networking: NetworkingProtocol
  private let tokenProvider: () -> String?

  init(tokenProvider: @escaping () -> String?) {
    self.tokenProvider = tokenProvider
    self.networking = InternalNetworking(tokenProvider: tokenProvider)
  }

  func getToken() -> String? {
    return self.tokenProvider()
  }

  // Note: Direct session access is no longer available for iOS parity
  // Use the request methods instead

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

  func request<T: Decodable>(
    _ method: String,
    _ path: String,
    body: (some Encodable)? = nil,
    queryParameters: [String: String] = [:]
  ) async throws -> T {
    return try await self.networking.request(method, path, body: body, queryParameters: queryParameters)
  }

  // MARK: - Error Response Parsing

  // Note: Error parsing is now handled by InternalNetworking

  func getRawResponse(endpoint: String, params: [String: String] = [:]) async throws -> Data {
    return try await self.networking.getRawResponse(endpoint: endpoint, params: params)
  }
}
