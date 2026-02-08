import Foundation
@testable import focusmate

final class MockNetworking: NetworkingProtocol {

    // MARK: - Call Recording

    struct Call {
        let method: String
        let path: String
        let body: Data?
        let queryParameters: [String: String]
    }

    private(set) var calls: [Call] = []

    var lastCall: Call? { calls.last }

    var lastBodyJSON: [String: Any]? {
        guard let data = lastCall?.body else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    // MARK: - Stubbing

    var stubbedData: Data = Data()
    var stubbedError: Error?

    func stubJSON<T: Encodable>(_ value: T) {
        stubbedData = (try? JSONEncoder().encode(value)) ?? Data()
    }

    func reset() {
        calls = []
        stubbedData = Data()
        stubbedError = nil
    }

    // MARK: - NetworkingProtocol

    func request<T: Decodable>(
        _ method: String,
        _ path: String,
        body: (some Encodable)?,
        queryParameters: [String: String],
        idempotencyKey: String?
    ) async throws -> T {
        let bodyData: Data?
        if let body {
            bodyData = try? APIClient.encoder.encode(body)
        } else {
            bodyData = nil
        }

        calls.append(Call(
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

        return try APIClient.decoder.decode(T.self, from: stubbedData)
    }

    func getRawResponse(endpoint: String, params: [String: String]) async throws -> Data {
        calls.append(Call(method: "GET", path: endpoint, body: nil, queryParameters: params))
        if let error = stubbedError {
            throw error
        }
        return stubbedData
    }
}
