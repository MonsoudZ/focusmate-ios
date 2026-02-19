@testable import focusmate
import XCTest

final class ListServiceTests: XCTestCase {
  private var mock: MockNetworking!
  private var service: ListService!

  override func setUp() async throws {
    try await super.setUp()
    self.mock = MockNetworking()
    let apiClient = APIClient(tokenProvider: { nil }, networking: mock)
    self.service = ListService(apiClient: apiClient)
    // Clear shared cache to avoid cross-test pollution
    await ResponseCache.shared.invalidateAll()
  }

  override func tearDown() async throws {
    await ResponseCache.shared.invalidateAll()
    try await super.tearDown()
  }

  // MARK: - Helpers

  private func stubListsResponse(_ lists: [ListDTO] = []) {
    let response = ListsResponse(lists: lists, tombstones: nil)
    self.mock.stubJSON(response)
  }

  private func stubSingleList(_ list: ListDTO? = nil) {
    let response = ListResponse(list: list ?? TestFactories.makeSampleList())
    self.mock.stubJSON(response)
  }

  // MARK: - fetchLists

  func testFetchListsDecodesResponse() async throws {
    let list = TestFactories.makeSampleList(id: 3, name: "Work")
    self.stubListsResponse([list])

    let result = try await service.fetchLists()

    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result.first?.id, 3)
    XCTAssertEqual(result.first?.name, "Work")
    XCTAssertEqual(self.mock.lastCall?.method, "GET")
    XCTAssertEqual(self.mock.lastCall?.path, API.Lists.root)
  }

  func testFetchListsUsesCacheOnSecondCall() async throws {
    self.stubListsResponse([TestFactories.makeSampleList()])

    _ = try await self.service.fetchLists()
    XCTAssertEqual(self.mock.calls.count, 1)

    // Second call should use cache
    _ = try await self.service.fetchLists()
    XCTAssertEqual(self.mock.calls.count, 1, "Second call should not make a network request")
  }

  func testFetchListsBypassesCacheAfterInvalidation() async throws {
    self.stubListsResponse([TestFactories.makeSampleList()])

    _ = try await self.service.fetchLists()
    XCTAssertEqual(self.mock.calls.count, 1)

    await ResponseCache.shared.invalidate("lists")

    _ = try await self.service.fetchLists()
    XCTAssertEqual(self.mock.calls.count, 2, "Should re-fetch after cache invalidation")
  }

  // MARK: - createList

  func testCreateListSendsCorrectBody() async throws {
    self.stubSingleList()

    _ = try await self.service.createList(name: "New List", description: "Desc", color: "red")

    XCTAssertEqual(self.mock.lastCall?.method, "POST")
    XCTAssertEqual(self.mock.lastCall?.path, API.Lists.root)

    let body = self.mock.lastBodyJSON
    let listBody = body?["list"] as? [String: Any]
    XCTAssertEqual(listBody?["name"] as? String, "New List")
    XCTAssertEqual(listBody?["description"] as? String, "Desc")
    XCTAssertEqual(listBody?["color"] as? String, "red")
  }

  func testCreateListWritesThroughCache() async throws {
    // Populate cache with one list
    let existing = TestFactories.makeSampleList(id: 1, name: "Existing")
    self.stubListsResponse([existing])
    _ = try await self.service.fetchLists()
    XCTAssertEqual(self.mock.calls.count, 1)

    // Create list — should write through to cache
    let created = TestFactories.makeSampleList(id: 2, name: "New")
    self.stubSingleList(created)
    _ = try await self.service.createList(name: "New", description: nil)
    XCTAssertEqual(self.mock.calls.count, 2)

    // Next fetch should serve from cache (no network hit) with both lists
    let lists = try await service.fetchLists()
    XCTAssertEqual(self.mock.calls.count, 2, "Should serve from write-through cache")
    XCTAssertEqual(lists.count, 2)
    XCTAssertEqual(lists.map(\.id), [1, 2])
  }

  // MARK: - updateList

  func testUpdateListSendsCorrectBody() async throws {
    self.stubSingleList()

    _ = try await self.service.updateList(id: 5, name: "Renamed", description: "New desc", color: "green")

    XCTAssertEqual(self.mock.lastCall?.method, "PUT")
    XCTAssertEqual(self.mock.lastCall?.path, API.Lists.id("5"))

    let body = self.mock.lastBodyJSON
    let listBody = body?["list"] as? [String: Any]
    XCTAssertEqual(listBody?["name"] as? String, "Renamed")
    XCTAssertEqual(listBody?["description"] as? String, "New desc")
    XCTAssertEqual(listBody?["color"] as? String, "green")
  }

  // MARK: - deleteList

  func testDeleteListCallsCorrectEndpoint() async throws {
    try await self.service.deleteList(id: 7)

    XCTAssertEqual(self.mock.lastCall?.method, "DELETE")
    XCTAssertEqual(self.mock.lastCall?.path, API.Lists.id("7"))
  }

  func testDeleteListWritesThroughCache() async throws {
    // Populate cache with two lists
    let lists = [
      TestFactories.makeSampleList(id: 1, name: "Keep"),
      TestFactories.makeSampleList(id: 2, name: "Delete"),
    ]
    self.stubListsResponse(lists)
    _ = try await self.service.fetchLists()
    XCTAssertEqual(self.mock.calls.count, 1)

    // Delete list 2 — should remove from cache
    try await self.service.deleteList(id: 2)
    XCTAssertEqual(self.mock.calls.count, 2)

    // Next fetch should serve from cache with list 2 removed
    let result = try await service.fetchLists()
    XCTAssertEqual(self.mock.calls.count, 2, "Should serve from write-through cache")
    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result.first?.id, 1)
  }

  // MARK: - createList with listType

  func testCreateListSendsListType() async throws {
    self.stubSingleList()

    _ = try await self.service.createList(name: "Habits", description: nil, color: "orange", listType: "habit_tracker")

    let body = self.mock.lastBodyJSON
    let listBody = body?["list"] as? [String: Any]
    XCTAssertEqual(listBody?["list_type"] as? String, "habit_tracker")
  }

  func testCreateListOmitsListTypeWhenNil() async throws {
    self.stubSingleList()

    _ = try await self.service.createList(name: "Plain", description: nil)

    let body = self.mock.lastBodyJSON
    let listBody = body?["list"] as? [String: Any]
    XCTAssertNil(listBody?["list_type"])
  }

  // MARK: - Raw JSON Decoding (backend shape fidelity)

  func testFetchListsDecodesBackendMembersWithoutEmail() async throws {
    // Real backend response: members have no email field
    let json = """
    {
      "lists": [{
        "id": 1, "name": "Test", "description": null, "visibility": "private",
        "color": "blue", "role": "owner", "tasks_count": 0,
        "completed_tasks_count": 0, "overdue_tasks_count": 0,
        "members": [{"id": 1, "name": "Alice", "role": "owner"}],
        "created_at": "2026-01-01T00:00:00Z", "updated_at": "2026-01-01T00:00:00Z"
      }],
      "tombstones": []
    }
    """.data(using: .utf8)!
    self.mock.stubbedData = json

    let result = try await service.fetchLists()

    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result.first?.members?.count, 1)
    XCTAssertEqual(result.first?.members?.first?.name, "Alice")
    XCTAssertNil(result.first?.members?.first?.email)
    XCTAssertEqual(result.first?.members?.first?.displayName, "Alice")
  }

  func testFetchListsDecodesBackendMembersWithEmail() async throws {
    let json = """
    {
      "lists": [{
        "id": 1, "name": "Test", "description": null, "visibility": "private",
        "color": "blue", "role": "owner", "tasks_count": 0,
        "completed_tasks_count": 0, "overdue_tasks_count": 0,
        "members": [{"id": 1, "name": null, "email": "alice@test.com", "role": "owner"}],
        "created_at": "2026-01-01T00:00:00Z", "updated_at": "2026-01-01T00:00:00Z"
      }],
      "tombstones": []
    }
    """.data(using: .utf8)!
    self.mock.stubbedData = json

    let result = try await service.fetchLists()

    XCTAssertEqual(result.first?.members?.first?.displayName, "alice@test.com")
  }

  func testDisplayNameFallsBackToMemberWhenBothNil() {
    let member = ListMemberDTO(id: 1, name: nil, email: nil, role: "owner")
    XCTAssertEqual(member.displayName, "Member")
  }

  // MARK: - TaskCreatorDTO decoding

  func testTaskCreatorDecodesWithoutEmail() throws {
    let json = """
    {"id": 1, "name": "Alice", "role": "client"}
    """.data(using: .utf8)!
    let creator = try APIClient.decoder.decode(TaskCreatorDTO.self, from: json)

    XCTAssertEqual(creator.name, "Alice")
    XCTAssertNil(creator.email)
    XCTAssertEqual(creator.displayName, "Alice")
  }

  func testTaskCreatorDisplayNameFallsBackToEmail() throws {
    let json = """
    {"id": 1, "name": null, "email": "alice@test.com", "role": "client"}
    """.data(using: .utf8)!
    let creator = try APIClient.decoder.decode(TaskCreatorDTO.self, from: json)

    XCTAssertEqual(creator.displayName, "alice@test.com")
  }

  func testTaskCreatorDisplayNameFallsBackToMember() {
    let creator = TaskCreatorDTO(id: 1, email: nil, name: nil, role: nil)
    XCTAssertEqual(creator.displayName, "Member")
  }

  // MARK: - Error Propagation

  func testFetchListsPropagatesNetworkError() async {
    self.mock.stubbedError = APIError.noInternetConnection

    do {
      _ = try await self.service.fetchLists()
      XCTFail("Expected error to be thrown")
    } catch {
      // Error propagated
    }
  }
}
