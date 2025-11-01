import Foundation
@testable import focusmate

/// Mock API Client for testing
final class MockAPIClient {
  var shouldFail = false
  var mockError: Error?
  var mockDelay: TimeInterval = 0
  var requestCallCount = 0
  var lastRequestMethod: String?
  var lastRequestPath: String?

  // Mock responses for different endpoints
  var mockResponses: [String: Any] = [:]

  func reset() {
    shouldFail = false
    mockError = nil
    mockDelay = 0
    requestCallCount = 0
    lastRequestMethod = nil
    lastRequestPath = nil
    mockResponses = [:]
  }

  func setMockResponse<T: Encodable>(_ response: T, for path: String) {
    mockResponses[path] = response
  }
}

/// Mock NetworkingProtocol implementation
final class MockNetworking: NetworkingProtocol {
  var shouldFail = false
  var mockError: Error = APIError.badURL
  var mockDelay: TimeInterval = 0
  var requestCallCount = 0
  var mockResponses: [String: Any] = [:]

  func request<T: Decodable>(
    _ method: String,
    _ path: String,
    body: (some Encodable)?,
    queryParameters: [String: String]
  ) async throws -> T {
    requestCallCount += 1

    if mockDelay > 0 {
      try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
    }

    if shouldFail {
      throw mockError
    }

    // Return mock response if available
    if let response = mockResponses[path] as? T {
      return response
    }

    // Try to create empty response for common types
    if T.self == EmptyResponse.self {
      return EmptyResponse() as! T
    }

    throw APIError.decoding
  }

  func getRawResponse(endpoint: String, params: [String: String]) async throws -> Data {
    requestCallCount += 1

    if shouldFail {
      throw mockError
    }

    return Data()
  }
}
