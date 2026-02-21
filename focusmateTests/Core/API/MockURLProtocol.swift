import Foundation

final class MockURLProtocol: URLProtocol {
  struct Stub {
    let statusCode: Int
    let headers: [String: String]
    let body: Data
  }

  static var stub: Stub?
  static var error: Error?

  /// Per-request routing: when set, takes priority over the static `stub`/`error`.
  /// Return `(stub, nil)` for a successful stub, `(nil, error)` for an error,
  /// or `(nil, nil)` to fall back to the static properties.
  static var requestHandler: ((URLRequest) -> (Stub?, Error?))?

  override class func canInit(with request: URLRequest) -> Bool {
    true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    // Per-request routing takes priority
    if let handler = Self.requestHandler {
      let (handlerStub, handlerError) = handler(request)
      if let handlerError {
        client?.urlProtocol(self, didFailWithError: handlerError)
        return
      }
      if let handlerStub {
        deliverStub(handlerStub)
        return
      }
      // (nil, nil) → fall through to static stub/error
    }

    if let error = Self.error {
      client?.urlProtocol(self, didFailWithError: error)
      return
    }

    let stub = Self.stub ?? Stub(statusCode: 200, headers: [:], body: Data())

    deliverStub(stub)
  }

  private func deliverStub(_ stub: Stub) {
    guard let url = request.url else {
      preconditionFailure("MockURLProtocol received request without URL")
    }

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
