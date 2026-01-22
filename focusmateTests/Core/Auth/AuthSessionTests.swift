import XCTest
@testable import focusmate


final class AuthSessionTests: XCTestCase {

    func testAccessThrowsWhenNoToken() async {
        let session = AuthSession()

        do {
            _ = try await session.access()
            XCTFail("Expected access() to throw when no token is set")
        } catch let err as APIError {
            // If you have a specific case, match it here.
            // Example:
            // switch err { case .unauthorized: break; default: XCTFail("...") }
            // If you don't, at least prove it's the right error type:
            _ = err
        } catch {
            XCTFail("Expected APIError but got: \(error)")
        }
    }

    func testAccessReturnsTokenWhenSet() async throws {
        let session = AuthSession()
        await session.set(token: "test-token")

        let token = try await session.access()
        XCTAssertEqual(token, "test-token")
    }

    func testClearRemovesToken() async {
        let session = AuthSession()
        await session.set(token: "test-token")
        await session.clear()

        do {
            _ = try await session.access()
            XCTFail("Expected access() to throw after clear()")
        } catch let err as APIError {
            _ = err
        } catch {
            XCTFail("Expected APIError but got: \(error)")
        }
    }

    func testIsLoggedInReflectsTokenState() async {
        let session = AuthSession()

        // ✅ No `await` inside XCTAssert
        let loggedOutInitially = await session.isLoggedIn
        XCTAssertFalse(loggedOutInitially)

        await session.set(token: "test-token")

        let loggedInAfterSet = await session.isLoggedIn
        XCTAssertTrue(loggedInAfterSet)

        await session.clear()

        let loggedOutAfterClear = await session.isLoggedIn
        XCTAssertFalse(loggedOutAfterClear)
    }
}
