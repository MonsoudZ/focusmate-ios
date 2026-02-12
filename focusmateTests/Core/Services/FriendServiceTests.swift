import XCTest
@testable import focusmate

final class FriendServiceTests: XCTestCase {

    private var mock: MockNetworking!
    private var service: FriendService!

    override func setUp() {
        super.setUp()
        mock = MockNetworking()
        let apiClient = APIClient(tokenProvider: { nil }, networking: mock)
        service = FriendService(apiClient: apiClient)
    }

    // MARK: - fetchFriends

    func testFetchFriendsDecodesResponse() async throws {
        let friend = TestFactories.makeSampleFriend(id: 5, name: "Bob")
        mock.stubJSON(FriendsResponse(friends: [friend]))

        let result = try await service.fetchFriends()

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, 5)
        XCTAssertEqual(result.first?.name, "Bob")
    }

    func testFetchFriendsCallsCorrectEndpoint() async throws {
        mock.stubJSON(FriendsResponse(friends: []))

        _ = try await service.fetchFriends()

        XCTAssertEqual(mock.lastCall?.method, "GET")
        XCTAssertEqual(mock.lastCall?.path, API.Friends.list)
    }

    func testFetchFriendsPropagatesError() async {
        mock.stubbedError = APIError.unauthorized(nil)

        do {
            _ = try await service.fetchFriends()
            XCTFail("Expected error to be thrown")
        } catch {
            // Error propagated
        }
    }

    // MARK: - removeFriend

    func testRemoveFriendCallsCorrectEndpoint() async throws {
        try await service.removeFriend(id: 7)

        XCTAssertEqual(mock.lastCall?.method, "DELETE")
        XCTAssertEqual(mock.lastCall?.path, API.Friends.friend("7"))
    }

    func testRemoveFriendRejectsNegativeId() async {
        do {
            try await service.removeFriend(id: -1)
            XCTFail("Expected validation error")
        } catch {
            // Validation rejects negative IDs
        }
    }

    func testRemoveFriendPropagatesError() async {
        mock.stubbedError = APIError.unauthorized(nil)

        do {
            try await service.removeFriend(id: 1)
            XCTFail("Expected error to be thrown")
        } catch {
            // Error propagated
        }
    }

    // MARK: - addFriendToList

    func testAddFriendToListSendsCorrectBody() async throws {
        let membership = TestFactories.makeSampleMembership()
        mock.stubJSON(MembershipResponse(membership: membership))

        _ = try await service.addFriendToList(listId: 3, friendId: 5, role: "editor")

        XCTAssertEqual(mock.lastCall?.method, "POST")
        XCTAssertEqual(mock.lastCall?.path, API.Lists.memberships("3"))

        let body = mock.lastBodyJSON
        let membershipBody = body?["membership"] as? [String: Any]
        XCTAssertEqual(membershipBody?["user_id"] as? Int, 5)
        XCTAssertEqual(membershipBody?["role"] as? String, "editor")
    }

    func testAddFriendToListCallsCorrectEndpoint() async throws {
        let membership = TestFactories.makeSampleMembership()
        mock.stubJSON(MembershipResponse(membership: membership))

        _ = try await service.addFriendToList(listId: 10, friendId: 2, role: "viewer")

        XCTAssertEqual(mock.lastCall?.method, "POST")
        XCTAssertEqual(mock.lastCall?.path, API.Lists.memberships("10"))
    }

    func testAddFriendToListRejectsNegativeListId() async {
        do {
            _ = try await service.addFriendToList(listId: -1, friendId: 1, role: "viewer")
            XCTFail("Expected validation error")
        } catch {
            // Validation rejects negative IDs
        }
    }

    func testAddFriendToListRejectsNegativeFriendId() async {
        do {
            _ = try await service.addFriendToList(listId: 1, friendId: -1, role: "viewer")
            XCTFail("Expected validation error")
        } catch {
            // Validation rejects negative IDs
        }
    }

    func testAddFriendToListRejectsInvalidRole() async {
        do {
            _ = try await service.addFriendToList(listId: 1, friendId: 1, role: "admin")
            XCTFail("Expected validation error")
        } catch {
            // Role validation rejects invalid roles
        }
    }
}
