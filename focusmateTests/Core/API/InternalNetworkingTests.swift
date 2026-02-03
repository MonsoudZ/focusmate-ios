import XCTest
@testable import focusmate
import Combine

final class InternalNetworkingTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MockURLProtocol.stub = nil
        MockURLProtocol.error = nil
        Thread.sleep(forTimeInterval: 1.1) // avoid unauthorized throttle interference
    }

    private func makeNetworking(token: String? = nil) -> InternalNetworking {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        let session = URLSession(configuration: config)

        let pinning = CertificatePinning(pinnedDomains: [], publicKeyHashes: [], enforceInDebug: false)

        return InternalNetworking(
            tokenProvider: { token },
            session: session,
            certificatePinning: pinning
        )
    }

    func test401ThrowsUnauthorizedAndSendsUnauthorizedEvent() async {
        let networking = makeNetworking(token: "jwt-123")

        let exp = expectation(description: "unauthorized event")
        let cancellable = await MainActor.run {
            AuthEventBus.shared.publisher.sink { event in
                if event == .unauthorized { exp.fulfill() }
            }
        }
        defer { cancellable.cancel() }

        MockURLProtocol.stub = .init(
            statusCode: 401,
            headers: ["Content-Type": "application/json"],
            body: Data()
        )

        do {
            let _: UserDTO = try await networking.request(
                "GET",
                API.Users.profile,
                body: nil as String?,
                queryParameters: [:],
                idempotencyKey: nil
            )
            XCTFail("Expected to throw APIError.unauthorized")
        } catch let err as APIError {
            guard case .unauthorized(_) = err else {
                return XCTFail("Expected .unauthorized but got \(err)")
            }
        } catch {
            XCTFail("Expected APIError but got \(error)")
        }

        await fulfillment(of: [exp], timeout: 1.0)
    }

    func test429ParsesRetryAfterHeader() async {
        let networking = makeNetworking()

        MockURLProtocol.stub = .init(
            statusCode: 429,
            headers: ["Retry-After": "7", "Content-Type": "application/json"],
            body: Data()
        )

        do {
            let _: UserDTO = try await networking.request(
                "GET",
                API.Users.profile,
                body: nil as String?,
                queryParameters: [:],
                idempotencyKey: nil
            )
            XCTFail("Expected to throw rateLimited")
        } catch let err as APIError {
            guard case .rateLimited(let seconds) = err else {
                return XCTFail("Expected .rateLimited but got \(err)")
            }
            XCTAssertEqual(seconds, 7)
        } catch {
            XCTFail("Expected APIError but got \(error)")
        }
    }

    func testTimedOutMapsToTimeout() async {
        let networking = makeNetworking()
        MockURLProtocol.error = URLError(.timedOut)

        do {
            let _: UserDTO = try await networking.request(
                "GET",
                API.Users.profile,
                body: nil as String?,
                queryParameters: [:],
                idempotencyKey: nil
            )
            XCTFail("Expected to throw timeout")
        } catch let err as APIError {
            guard case .timeout = err else {
                return XCTFail("Expected .timeout but got \(err)")
            }
        } catch {
            XCTFail("Expected APIError but got \(error)")
        }
    }

    func testNoInternetMapsToNoInternetConnection() async {
        let networking = makeNetworking()
        MockURLProtocol.error = URLError(.notConnectedToInternet)

        do {
            let _: UserDTO = try await networking.request(
                "GET",
                API.Users.profile,
                body: nil as String?,
                queryParameters: [:],
                idempotencyKey: nil
            )
            XCTFail("Expected to throw noInternetConnection")
        } catch let err as APIError {
            guard case .noInternetConnection = err else {
                return XCTFail("Expected .noInternetConnection but got \(err)")
            }
        } catch {
            XCTFail("Expected APIError but got \(error)")
        }
    }
}
