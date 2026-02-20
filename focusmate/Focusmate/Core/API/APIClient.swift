import Foundation

final class APIClient {
  private let networking: NetworkingProtocol
  private let tokenProvider: () -> String?

  // MARK: - Initializers

  /// Production init
  init(tokenProvider: @escaping () -> String?) {
    self.tokenProvider = tokenProvider
    self.networking = InternalNetworking(tokenProvider: tokenProvider)
  }

  /// DI init (used for tests, previews, and swapping transport implementations cleanly)
  init(tokenProvider: @escaping () -> String?, networking: NetworkingProtocol) {
    self.tokenProvider = tokenProvider
    self.networking = networking
  }

  func getToken() -> String? {
    return self.tokenProvider()
  }

  // MARK: - JSON Coding

  static let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()

  static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }()

  // MARK: - Requests

  func request<T: Decodable>(
    _ method: String,
    _ path: String,
    body: (some Encodable)? = nil,
    queryParameters: [String: String] = [:],
    idempotencyKey: String? = nil
  ) async throws -> T {
    return try await self.networking.request(
      method,
      path,
      body: body,
      queryParameters: queryParameters,
      idempotencyKey: idempotencyKey
    )
  }

}
