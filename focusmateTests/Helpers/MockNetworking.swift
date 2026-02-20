@testable import focusmate
import Foundation

final class MockNetworking: NetworkingProtocol {
  // MARK: - Call Recording

  struct Call {
    let method: String
    let path: String
    let body: Data?
    let queryParameters: [String: String]
  }

  private(set) var calls: [Call] = []

  var lastCall: Call? {
    self.calls.last
  }

  var lastBodyJSON: [String: Any]? {
    guard let data = lastCall?.body else { return nil }
    return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
  }

  // MARK: - Stubbing

  var stubbedData: Data = .init()
  var stubbedError: Error?

  func stubJSON(_ value: some Encodable) {
    self.stubbedData = (try? JSONEncoder().encode(value)) ?? Data()
  }

  func reset() {
    self.calls = []
    self.stubbedData = Data()
    self.stubbedError = nil
  }

  // MARK: - NetworkingProtocol

  func request<T: Decodable>(
    _ method: String,
    _ path: String,
    body: (some Encodable)?,
    queryParameters: [String: String],
    idempotencyKey: String?
  ) async throws -> T {
    let bodyData: Data? = if let body {
      try? APIClient.encoder.encode(body)
    } else {
      nil
    }

    self.calls.append(Call(
      method: method,
      path: path,
      body: bodyData,
      queryParameters: queryParameters
    ))

    if let error = stubbedError {
      throw error
    }

    if T.self == EmptyResponse.self {
      guard let empty = EmptyResponse() as? T else {
        preconditionFailure("EmptyResponse could not be cast to \(T.self)")
      }
      return empty
    }

    return try APIClient.decoder.decode(T.self, from: self.stubbedData)
  }

}
