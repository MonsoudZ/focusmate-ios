import XCTest
@testable import focusmate

@MainActor
final class AuthStoreUnauthorizedTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Ensure clean state
        KeychainManager.shared.clear()
        // Avoid throttle interference if another test sent unauthorized recently
        Thread.sleep(forTimeInterval: 1.1)
    }

    override func tearDown() {
        KeychainManager.shared.clear()
        super.tearDown()
    }

    func testUnauthorizedEventClearsLocalSession() async {
        // Arrange: put a token in keychain so AuthStore loads it on init
        KeychainManager.shared.save(token: "jwt-123")

        let store = AuthStore()

        // Precondition: token loaded
        XCTAssertNotNil(store.jwt)

        // Act
        AuthEventBus.shared.send(.unauthorized)

        // Allow async Task in the event sink to execute
        try? await Task.sleep(nanoseconds: 300_000_000)

        // Assert
        XCTAssertNil(store.jwt)
        XCTAssertNil(store.currentUser)
        XCTAssertNil(KeychainManager.shared.load())
    }
}
