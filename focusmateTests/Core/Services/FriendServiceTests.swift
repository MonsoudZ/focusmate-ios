@testable import focusmate
import XCTest

final class FriendServiceTests: XCTestCase {
  private var mock: MockNetworking!
  private var service: FriendService!

  override func setUp() {
    super.setUp()
    self.mock = MockNetworking()
    let apiClient = APIClient(tokenProvider: { nil }, networking: mock)
    self.service = FriendService(apiClient: apiClient)
  }

  // MARK: - fetchFriends

  func testFetchFriendsDecodesResponse() async throws {
    let friend = TestFactories.makeSampleFriend(id: 5, name: "Bob")
    self.mock.stubJSON(FriendsResponse(friends: [friend]))

    let result = try await service.fetchFriends()

    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result.first?.id, 5)
    XCTAssertEqual(result.first?.name, "Bob")
  }

  func testFetchFriendsCallsCorrectEndpoint() async throws {
    self.mock.stubJSON(FriendsResponse(friends: []))

    _ = try await self.service.fetchFriends()

    XCTAssertEqual(self.mock.lastCall?.method, "GET")
    XCTAssertEqual(self.mock.lastCall?.path, API.Friends.list)
  }

  func testFetchFriendsPropagatesError() async {
    self.mock.stubbedError = APIError.unauthorized(nil)

    do {
      _ = try await self.service.fetchFriends()
      XCTFail("Expected error to be thrown")
    } catch {
      // Error propagated
    }
  }

  // MARK: - removeFriend

  func testRemoveFriendCallsCorrectEndpoint() async throws {
    try await self.service.removeFriend(id: 7)

    XCTAssertEqual(self.mock.lastCall?.method, "DELETE")
    XCTAssertEqual(self.mock.lastCall?.path, API.Friends.friend("7"))
  }

  func testRemoveFriendRejectsNegativeId() async {
    do {
      try await self.service.removeFriend(id: -1)
      XCTFail("Expected validation error")
    } catch {
      // Validation rejects negative IDs
    }
  }

  func testRemoveFriendPropagatesError() async {
    self.mock.stubbedError = APIError.unauthorized(nil)

    do {
      try await self.service.removeFriend(id: 1)
      XCTFail("Expected error to be thrown")
    } catch {
      // Error propagated
    }
  }

  // MARK: - addFriendToList

  func testAddFriendToListSendsCorrectBody() async throws {
    let membership = TestFactories.makeSampleMembership()
    self.mock.stubJSON(MembershipResponse(membership: membership))

    _ = try await self.service.addFriendToList(listId: 3, friendId: 5, role: "editor")

    XCTAssertEqual(self.mock.lastCall?.method, "POST")
    XCTAssertEqual(self.mock.lastCall?.path, API.Lists.memberships("3"))

    let body = self.mock.lastBodyJSON
    let membershipBody = body?["membership"] as? [String: Any]
    XCTAssertEqual(membershipBody?["user_id"] as? Int, 5)
    XCTAssertEqual(membershipBody?["role"] as? String, "editor")
  }

  func testAddFriendToListCallsCorrectEndpoint() async throws {
    let membership = TestFactories.makeSampleMembership()
    self.mock.stubJSON(MembershipResponse(membership: membership))

    _ = try await self.service.addFriendToList(listId: 10, friendId: 2, role: "viewer")

    XCTAssertEqual(self.mock.lastCall?.method, "POST")
    XCTAssertEqual(self.mock.lastCall?.path, API.Lists.memberships("10"))
  }

  func testAddFriendToListRejectsNegativeListId() async {
    do {
      _ = try await self.service.addFriendToList(listId: -1, friendId: 1, role: "viewer")
      XCTFail("Expected validation error")
    } catch {
      // Validation rejects negative IDs
    }
  }

  func testAddFriendToListRejectsNegativeFriendId() async {
    do {
      _ = try await self.service.addFriendToList(listId: 1, friendId: -1, role: "viewer")
      XCTFail("Expected validation error")
    } catch {
      // Validation rejects negative IDs
    }
  }

  func testAddFriendToListRejectsInvalidRole() async {
    do {
      _ = try await self.service.addFriendToList(listId: 1, friendId: 1, role: "admin")
      XCTFail("Expected validation error")
    } catch {
      // Role validation rejects invalid roles
    }
  }
}
