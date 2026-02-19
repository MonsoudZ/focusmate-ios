@testable import focusmate
import XCTest

final class InviteServiceTests: XCTestCase {
  private var mock: MockNetworking!
  private var service: InviteService!

  override func setUp() {
    super.setUp()
    self.mock = MockNetworking()
    let apiClient = APIClient(tokenProvider: { nil }, networking: mock)
    self.service = InviteService(apiClient: apiClient)
  }

  // MARK: - fetchInvites

  func testFetchInvitesDecodesResponse() async throws {
    let invite = TestFactories.makeSampleInvite(id: 7, code: "XYZ")
    self.mock.stubJSON(InvitesResponse(invites: [invite]))

    let result = try await service.fetchInvites(listId: 1)

    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result.first?.id, 7)
    XCTAssertEqual(result.first?.code, "XYZ")
  }

  func testFetchInvitesCallsCorrectEndpoint() async throws {
    self.mock.stubJSON(InvitesResponse(invites: []))

    _ = try await self.service.fetchInvites(listId: 42)

    XCTAssertEqual(self.mock.lastCall?.method, "GET")
    XCTAssertEqual(self.mock.lastCall?.path, API.Lists.invites("42"))
  }

  func testFetchInvitesRejectsNegativeListId() async {
    do {
      _ = try await self.service.fetchInvites(listId: -1)
      XCTFail("Expected validation error")
    } catch {
      // Validation rejects negative IDs
    }
  }

  // MARK: - createInvite

  func testCreateInviteSendsCorrectBody() async throws {
    let invite = TestFactories.makeSampleInvite()
    self.mock.stubJSON(InviteResponse(invite: invite))

    _ = try await self.service.createInvite(listId: 5, role: "editor", maxUses: 10)

    XCTAssertEqual(self.mock.lastCall?.method, "POST")
    XCTAssertEqual(self.mock.lastCall?.path, API.Lists.invites("5"))

    let body = self.mock.lastBodyJSON
    let inviteBody = body?["invite"] as? [String: Any]
    XCTAssertEqual(inviteBody?["role"] as? String, "editor")
    XCTAssertEqual(inviteBody?["max_uses"] as? Int, 10)
  }

  func testCreateInviteCallsCorrectEndpoint() async throws {
    self.mock.stubJSON(InviteResponse(invite: TestFactories.makeSampleInvite()))

    _ = try await self.service.createInvite(listId: 3)

    XCTAssertEqual(self.mock.lastCall?.method, "POST")
    XCTAssertEqual(self.mock.lastCall?.path, API.Lists.invites("3"))
  }

  func testCreateInviteOmitsNilOptionals() async throws {
    self.mock.stubJSON(InviteResponse(invite: TestFactories.makeSampleInvite()))

    _ = try await self.service.createInvite(listId: 1)

    let body = self.mock.lastBodyJSON
    let inviteBody = body?["invite"] as? [String: Any]
    XCTAssertNil(inviteBody?["expires_at"])
    XCTAssertNil(inviteBody?["max_uses"])
  }

  func testCreateInviteRejectsNegativeListId() async {
    do {
      _ = try await self.service.createInvite(listId: -1)
      XCTFail("Expected validation error")
    } catch {
      // Validation rejects negative IDs
    }
  }

  // MARK: - revokeInvite

  func testRevokeInviteCallsCorrectEndpoint() async throws {
    try await self.service.revokeInvite(listId: 5, inviteId: 10)

    XCTAssertEqual(self.mock.lastCall?.method, "DELETE")
    XCTAssertEqual(self.mock.lastCall?.path, API.Lists.invite("5", "10"))
  }

  func testRevokeInviteRejectsNegativeListId() async {
    do {
      try await self.service.revokeInvite(listId: -1, inviteId: 1)
      XCTFail("Expected validation error")
    } catch {
      // Validation rejects negative IDs
    }
  }

  func testRevokeInviteRejectsNegativeInviteId() async {
    do {
      try await self.service.revokeInvite(listId: 1, inviteId: -1)
      XCTFail("Expected validation error")
    } catch {
      // Validation rejects negative IDs
    }
  }

  // MARK: - previewInvite

  func testPreviewInviteDecodesResponse() async throws {
    let preview = TestFactories.makeSampleInvitePreview(code: "PREV", listName: "My List")
    self.mock.stubJSON(InvitePreviewResponse(invite: preview))

    let result = try await service.previewInvite(code: "PREV")

    XCTAssertEqual(result.code, "PREV")
    XCTAssertEqual(result.listName, "My List")
  }

  func testPreviewInviteCallsCorrectEndpoint() async throws {
    self.mock.stubJSON(InvitePreviewResponse(invite: TestFactories.makeSampleInvitePreview()))

    _ = try await self.service.previewInvite(code: "ABC")

    XCTAssertEqual(self.mock.lastCall?.method, "GET")
    XCTAssertEqual(self.mock.lastCall?.path, API.Invites.preview("ABC"))
  }

  func testPreviewInviteRejectsEmptyCode() async {
    do {
      _ = try await self.service.previewInvite(code: "")
      XCTFail("Expected validation error")
    } catch {
      // Validation rejects empty strings
    }
  }

  // MARK: - acceptInvite

  func testAcceptInviteDecodesResponse() async throws {
    let list = TestFactories.makeSampleList(id: 99, name: "Joined List")
    let membership = TestFactories.makeSampleMembership()
    self.mock.stubJSON(AcceptInviteResponse(list: list, membership: membership))

    let result = try await service.acceptInvite(code: "JOIN")

    XCTAssertEqual(result.list.id, 99)
    XCTAssertEqual(result.list.name, "Joined List")
  }

  func testAcceptInviteCallsCorrectEndpoint() async throws {
    let list = TestFactories.makeSampleList()
    let membership = TestFactories.makeSampleMembership()
    self.mock.stubJSON(AcceptInviteResponse(list: list, membership: membership))

    _ = try await self.service.acceptInvite(code: "XYZ")

    XCTAssertEqual(self.mock.lastCall?.method, "POST")
    XCTAssertEqual(self.mock.lastCall?.path, API.Invites.accept("XYZ"))
  }

  func testAcceptInviteRejectsEmptyCode() async {
    do {
      _ = try await self.service.acceptInvite(code: "")
      XCTFail("Expected validation error")
    } catch {
      // Validation rejects empty strings
    }
  }
}
