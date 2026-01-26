import XCTest
@testable import focusmate

final class ListServiceTests: XCTestCase {

    private var mock: MockNetworking!
    private var service: ListService!

    override func setUp() async throws {
        try await super.setUp()
        mock = MockNetworking()
        let apiClient = APIClient(tokenProvider: { nil }, networking: mock)
        service = ListService(apiClient: apiClient)
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
        mock.stubJSON(response)
    }

    private func stubSingleList(_ list: ListDTO? = nil) {
        mock.stubJSON(list ?? TestFactories.makeSampleList())
    }

    // MARK: - fetchLists

    func testFetchListsDecodesResponse() async throws {
        let list = TestFactories.makeSampleList(id: 3, name: "Work")
        stubListsResponse([list])

        let result = try await service.fetchLists()

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, 3)
        XCTAssertEqual(result.first?.name, "Work")
        XCTAssertEqual(mock.lastCall?.method, "GET")
        XCTAssertEqual(mock.lastCall?.path, API.Lists.root)
    }

    func testFetchListsUsesCacheOnSecondCall() async throws {
        stubListsResponse([TestFactories.makeSampleList()])

        _ = try await service.fetchLists()
        XCTAssertEqual(mock.calls.count, 1)

        // Second call should use cache
        _ = try await service.fetchLists()
        XCTAssertEqual(mock.calls.count, 1, "Second call should not make a network request")
    }

    func testFetchListsBypassesCacheAfterInvalidation() async throws {
        stubListsResponse([TestFactories.makeSampleList()])

        _ = try await service.fetchLists()
        XCTAssertEqual(mock.calls.count, 1)

        await ResponseCache.shared.invalidate("lists")

        _ = try await service.fetchLists()
        XCTAssertEqual(mock.calls.count, 2, "Should re-fetch after cache invalidation")
    }

    // MARK: - createList

    func testCreateListSendsCorrectBody() async throws {
        stubSingleList()

        _ = try await service.createList(name: "New List", description: "Desc", color: "red")

        XCTAssertEqual(mock.lastCall?.method, "POST")
        XCTAssertEqual(mock.lastCall?.path, API.Lists.root)

        let body = mock.lastBodyJSON
        let listBody = body?["list"] as? [String: Any]
        XCTAssertEqual(listBody?["name"] as? String, "New List")
        XCTAssertEqual(listBody?["description"] as? String, "Desc")
        XCTAssertEqual(listBody?["color"] as? String, "red")
    }

    func testCreateListInvalidatesCache() async throws {
        // Populate cache
        stubListsResponse([TestFactories.makeSampleList()])
        _ = try await service.fetchLists()
        XCTAssertEqual(mock.calls.count, 1)

        // Create list — should invalidate cache
        stubSingleList()
        _ = try await service.createList(name: "New", description: nil)
        XCTAssertEqual(mock.calls.count, 2)

        // Re-stub for fetch
        stubListsResponse([TestFactories.makeSampleList()])

        // Next fetch should hit network
        _ = try await service.fetchLists()
        XCTAssertEqual(mock.calls.count, 3, "Cache should have been invalidated by createList")
    }

    // MARK: - updateList

    func testUpdateListSendsCorrectBody() async throws {
        stubSingleList()

        _ = try await service.updateList(id: 5, name: "Renamed", description: "New desc", color: "green")

        XCTAssertEqual(mock.lastCall?.method, "PUT")
        XCTAssertEqual(mock.lastCall?.path, API.Lists.id("5"))

        let body = mock.lastBodyJSON
        let listBody = body?["list"] as? [String: Any]
        XCTAssertEqual(listBody?["name"] as? String, "Renamed")
        XCTAssertEqual(listBody?["description"] as? String, "New desc")
        XCTAssertEqual(listBody?["color"] as? String, "green")
    }

    // MARK: - deleteList

    func testDeleteListCallsCorrectEndpoint() async throws {
        try await service.deleteList(id: 7)

        XCTAssertEqual(mock.lastCall?.method, "DELETE")
        XCTAssertEqual(mock.lastCall?.path, API.Lists.id("7"))
    }

    func testDeleteListInvalidatesCache() async throws {
        // Populate cache
        stubListsResponse([TestFactories.makeSampleList()])
        _ = try await service.fetchLists()
        XCTAssertEqual(mock.calls.count, 1)

        // Delete list — should invalidate cache
        try await service.deleteList(id: 1)
        XCTAssertEqual(mock.calls.count, 2)

        // Re-stub for fetch
        stubListsResponse([])
        _ = try await service.fetchLists()
        XCTAssertEqual(mock.calls.count, 3, "Cache should have been invalidated by deleteList")
    }

    // MARK: - Error Propagation

    func testFetchListsPropagatesNetworkError() async {
        mock.stubbedError = APIError.noInternetConnection

        do {
            _ = try await service.fetchLists()
            XCTFail("Expected error to be thrown")
        } catch {
            // Error propagated
        }
    }
}
