import Foundation

final class MockURLProtocol: URLProtocol {
  struct Stub {
    let statusCode: Int
    let headers: [String: String]
    let body: Data
  }

  static var stub: Stub?
  static var error: Error?

  override class func canInit(with request: URLRequest) -> Bool {
    true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    if let error = Self.error {
      client?.urlProtocol(self, didFailWithError: error)
      return
    }

    let stub = Self.stub ?? Stub(statusCode: 200, headers: [:], body: Data())

    // Use request URL or a valid fallback - precondition since this is test infrastructure
    guard let url = request.url else {
      preconditionFailure("MockURLProtocol received request without URL")
    }

    // HTTPURLResponse init can fail if URL scheme is invalid, but we control the URLs in tests
    guard let response = HTTPURLResponse(
      url: url,
      statusCode: stub.statusCode,
      httpVersion: "HTTP/1.1",
      headerFields: stub.headers
    ) else {
      preconditionFailure("Failed to create HTTPURLResponse for URL: \(url)")
    }

    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    if !stub.body.isEmpty {
      client?.urlProtocol(self, didLoad: stub.body)
    }
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}
