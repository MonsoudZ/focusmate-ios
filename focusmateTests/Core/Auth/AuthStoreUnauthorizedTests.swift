import XCTest
@testable import focusmate

@MainActor
final class AuthStoreUnauthorizedTests: XCTestCase {

    private var testKeychain: KeychainManaging!

    private final class FakeKeychain: KeychainManaging {
        var token: String?
        var refreshToken: String?
        @discardableResult func save(token: String) -> Bool { self.token = token; return true }
        func load() -> String? { token }
        func clear() { token = nil }
        @discardableResult func save(refreshToken: String) -> Bool { self.refreshToken = refreshToken; return true }
        func loadRefreshToken() -> String? { refreshToken }
        func clearRefreshToken() { refreshToken = nil }
    }

    override func setUp() {
        super.setUp()
        testKeychain = FakeKeychain()
    }

    override func tearDown() {
        testKeychain = nil
        super.tearDown()
    }

    func testUnauthorizedEventClearsLocalSession() async throws {
        let eventBus = AuthEventBus()
        guard let fakeKeychain = testKeychain as? FakeKeychain else {
            XCTFail("testKeychain must be FakeKeychain")
            return
        }
        fakeKeychain.token = "jwt-123"

        let store = AuthStore(
            keychain: testKeychain,
            networking: nil,
            autoValidateOnInit: false,
            eventBus: eventBus
        )

        // Precondition: token loaded
        XCTAssertNotNil(store.jwt)

        // Act
        eventBus.send(.unauthorized)

        // Allow async Task in the event sink to execute
        try await Task.sleep(nanoseconds: 300_000_000)

        // Assert
        XCTAssertNil(store.jwt)
        XCTAssertNil(store.currentUser)
        XCTAssertNil(testKeychain.load())
    }
}
