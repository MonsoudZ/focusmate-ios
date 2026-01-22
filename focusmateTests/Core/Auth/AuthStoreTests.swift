import XCTest
@testable import focusmate



final class AuthStoreTests: XCTestCase {

    // MARK: - Fakes

    private final class FakeKeychain: KeychainManaging {
        var token: String?
        func save(token: String) { self.token = token }
        func load() -> String? { token }
        func clear() { token = nil }
    }

    private final class MockNetworking: NetworkingProtocol {
        enum Mode {
            case successUser(UserDTO)
            case failure(Error)
        }

        var mode: Mode

        init(mode: Mode) { self.mode = mode }

        func request<T: Decodable>(
            _ method: String,
            _ path: String,
            body: (some Encodable)?,
            queryParameters: [String : String],
            idempotencyKey: String?
        ) async throws -> T {
            // Only handle the profile request in these tests.
            if method == "GET", path == API.Users.profile {
                switch mode {
                case .successUser(let user):
                    guard let typed = user as? T else { throw APIError.decoding }
                    return typed
                case .failure(let error):
                    throw error
                }
            }

            // If AuthStore calls anything else unexpectedly, fail loudly.
            throw APIError.badStatus(500, "Unexpected request: \(method) \(path)", nil)
        }

        func getRawResponse(endpoint: String, params: [String : String]) async throws -> Data {
            throw APIError.badStatus(500, "Unexpected raw request: \(endpoint)", nil)
        }
    }

    // MARK: - Tests

    func testInitLoadsJwtFromKeychainWithoutAutoValidate() async {
        let keychain = FakeKeychain()
        keychain.token = "jwt-123"

        let store = await MainActor.run {
            AuthStore(keychain: keychain, networking: nil, autoValidateOnInit: false)
        }

        let jwt = await MainActor.run { store.jwt }
        XCTAssertEqual(jwt, "jwt-123")
    }

    func testValidateSessionSuccessSetsCurrentUserAndKeepsJwt() async {
        let keychain = FakeKeychain()
        keychain.token = "jwt-123"

        let user = UserDTO(
            id: 1,
            email: "test@example.com",
            name: "Test User",
            role: "user",
            timezone: "America/New_York",
            hasPassword: true
        )

        let networking = MockNetworking(mode: .successUser(user))

        let store = await MainActor.run {
            AuthStore(keychain: keychain, networking: networking, autoValidateOnInit: false)
        }

        await MainActor.run { store.jwt = "jwt-123" }
        await store.validateSession()

        let currentUser = await MainActor.run { store.currentUser }
        let jwt = await MainActor.run { store.jwt }

        XCTAssertEqual(currentUser, user)
        XCTAssertEqual(jwt, "jwt-123")
        XCTAssertEqual(keychain.token, "jwt-123") // still there
    }

    func testValidateSessionFailureClearsJwtUserAndKeychain() async {
        let keychain = FakeKeychain()
        keychain.token = "jwt-123"

        let networking = MockNetworking(mode: .failure(APIError.unauthorized))

        let store = await MainActor.run {
            AuthStore(keychain: keychain, networking: networking, autoValidateOnInit: false)
        }

        await MainActor.run {
            store.jwt = "jwt-123"
            store.currentUser = UserDTO(
                id: 1,
                email: "test@example.com",
                name: "Test User",
                role: "user",
                timezone: "America/New_York",
                hasPassword: true
            )
        }

        await store.validateSession()

        let jwt = await MainActor.run { store.jwt }
        let currentUser = await MainActor.run { store.currentUser }

        XCTAssertNil(jwt)
        XCTAssertNil(currentUser)
        XCTAssertNil(keychain.token)
    }
}
