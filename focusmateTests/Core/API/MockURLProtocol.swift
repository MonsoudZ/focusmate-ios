import Foundation

final class MockURLProtocol: URLProtocol {

    struct Stub {
        let statusCode: Int
        let headers: [String: String]
        let body: Data
    }

    static var stub: Stub?
    static var error: Error?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let error = Self.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        let stub = Self.stub ?? Stub(statusCode: 200, headers: [:], body: Data())
        let url = request.url ?? URL(string: "https://example.com")!

        let response = HTTPURLResponse(
            url: url,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: stub.headers
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if !stub.body.isEmpty {
            client?.urlProtocol(self, didLoad: stub.body)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
