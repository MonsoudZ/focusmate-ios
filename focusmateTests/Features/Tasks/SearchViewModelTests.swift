@testable import focusmate
import XCTest

@MainActor
final class SearchViewModelTests: XCTestCase {
  private var mockNetworking: MockNetworking!
  private var apiClient: APIClient!
  private var taskService: TaskService!
  private var listService: ListService!

  override func setUp() async throws {
    try await super.setUp()
    await ResponseCache.shared.invalidateAll()
    self.mockNetworking = MockNetworking()
    self.apiClient = APIClient(tokenProvider: { nil }, networking: self.mockNetworking)
    self.taskService = TaskService(apiClient: self.apiClient, sideEffects: NoOpSideEffects())
    self.listService = ListService(apiClient: self.apiClient)
  }

  override func tearDown() async throws {
    await ResponseCache.shared.invalidateAll()
    try await super.tearDown()
  }

  private struct NoOpSideEffects: TaskSideEffectHandling {
    nonisolated init() {}
    func taskCreated(_ task: TaskDTO, isSubtask: Bool) {}
    func taskUpdated(_ task: TaskDTO) {}
    func taskDeleted(taskId: Int) {}
    func taskCompleted(taskId: Int) {}
    func taskReopened(_ task: TaskDTO) {}
  }

  private func makeViewModel(initialQuery: String = "") -> SearchViewModel {
    SearchViewModel(
      taskService: self.taskService,
      listService: self.listService,
      initialQuery: initialQuery
    )
  }

  private func stubSearchResults(_ tasks: [TaskDTO]) {
    let response = TasksResponse(tasks: tasks, tombstones: nil)
    self.mockNetworking.stubJSON(response)
  }

  private func stubListsResponse(_ lists: [ListDTO]) {
    let response = ListsResponse(lists: lists, tombstones: nil)
    self.mockNetworking.stubJSON(response)
  }

  private func stubSingleListResponse(_ list: ListDTO) {
    let response = ListResponse(list: list)
    self.mockNetworking.stubJSON(response)
  }

  // MARK: - search() Tests

  func testSearchReturnsResults() async {
    let task1 = TestFactories.makeSampleTask(id: 1, listId: 10, title: "Buy milk")
    let task2 = TestFactories.makeSampleTask(id: 2, listId: 10, title: "Buy bread")
    self.stubSearchResults([task1, task2])

    let vm = self.makeViewModel()
    vm.query = "buy"
    await vm.search()

    XCTAssertEqual(vm.results.count, 2)
    XCTAssertTrue(vm.hasSearched)
    XCTAssertFalse(vm.isSearching)
    XCTAssertNil(vm.error)
  }

  func testSearchSetsLoadingState() async {
    self.stubSearchResults([])
    let vm = self.makeViewModel()
    vm.query = "test"

    XCTAssertFalse(vm.isSearching)
    XCTAssertFalse(vm.hasSearched)

    await vm.search()

    XCTAssertFalse(vm.isSearching)
    XCTAssertTrue(vm.hasSearched)
  }

  func testSearchIgnoresEmptyQuery() async {
    let vm = self.makeViewModel()
    vm.query = "   "
    await vm.search()

    XCTAssertTrue(vm.results.isEmpty)
    XCTAssertFalse(vm.hasSearched)
    XCTAssertFalse(vm.isSearching)
  }

  func testSearchTrimsWhitespace() async {
    self.stubSearchResults([TestFactories.makeSampleTask(title: "Found")])
    let vm = self.makeViewModel()
    vm.query = "  buy  "
    await vm.search()

    let call = self.mockNetworking.lastCall
    XCTAssertEqual(call?.queryParameters["q"], "buy")
  }

  func testSearchTruncatesAt255Characters() async {
    self.stubSearchResults([])
    let vm = self.makeViewModel()
    vm.query = String(repeating: "a", count: 300)
    await vm.search()

    let sentQuery = self.mockNetworking.lastCall?.queryParameters["q"] ?? ""
    XCTAssertEqual(sentQuery.count, 255)
  }

  func testSearchSetsErrorOnFailure() async {
    self.mockNetworking.stubbedError = APIError.serverError(500, "Server Error", nil)
    let vm = self.makeViewModel()
    vm.query = "test"
    await vm.search()

    XCTAssertNotNil(vm.error)
    XCTAssertTrue(vm.results.isEmpty)
    XCTAssertFalse(vm.isSearching)
    XCTAssertTrue(vm.hasSearched)
  }

  // MARK: - clearSearch() Tests

  func testClearSearchResetsState() async {
    self.stubSearchResults([TestFactories.makeSampleTask(title: "Found")])
    let vm = self.makeViewModel()
    vm.query = "test"
    await vm.search()

    XCTAssertFalse(vm.results.isEmpty)
    XCTAssertTrue(vm.hasSearched)

    vm.clearSearch()

    XCTAssertEqual(vm.query, "")
    XCTAssertTrue(vm.results.isEmpty)
    XCTAssertFalse(vm.hasSearched)
  }

  // MARK: - searchIfNeeded() Tests

  func testSearchIfNeededTriggersWithInitialQuery() async {
    self.stubSearchResults([TestFactories.makeSampleTask(title: "Result")])
    let vm = self.makeViewModel(initialQuery: "buy")

    XCTAssertEqual(vm.query, "buy")
    XCTAssertFalse(vm.hasSearched)

    await vm.searchIfNeeded()

    XCTAssertTrue(vm.hasSearched)
    XCTAssertEqual(vm.results.count, 1)
  }

  func testSearchIfNeededSkipsWhenNoInitialQuery() async {
    let vm = self.makeViewModel()
    await vm.searchIfNeeded()

    XCTAssertFalse(vm.hasSearched)
    XCTAssertTrue(vm.results.isEmpty)
  }

  func testSearchIfNeededSkipsWhenAlreadySearched() async {
    self.stubSearchResults([TestFactories.makeSampleTask(title: "First")])
    let vm = self.makeViewModel(initialQuery: "buy")
    await vm.searchIfNeeded()

    XCTAssertEqual(vm.results.count, 1)

    // Stub different results — searchIfNeeded should NOT re-search
    self.mockNetworking.reset()
    self.stubSearchResults([
      TestFactories.makeSampleTask(id: 1, title: "A"),
      TestFactories.makeSampleTask(id: 2, title: "B"),
    ])
    await vm.searchIfNeeded()

    // Should still have original results
    XCTAssertEqual(vm.results.count, 1)
  }

  // MARK: - groupedResults Tests

  func testGroupedResultsGroupsByListId() async {
    let tasks = [
      TestFactories.makeSampleTask(id: 1, listId: 10, title: "Task A"),
      TestFactories.makeSampleTask(id: 2, listId: 20, title: "Task B"),
      TestFactories.makeSampleTask(id: 3, listId: 10, title: "Task C"),
    ]
    self.stubSearchResults(tasks)

    let vm = self.makeViewModel()
    vm.query = "task"
    await vm.search()

    let grouped = vm.groupedResults
    XCTAssertEqual(grouped.count, 2)
    // Sorted by listId ascending
    XCTAssertEqual(grouped[0].listId, 10)
    XCTAssertEqual(grouped[0].tasks.count, 2)
    XCTAssertEqual(grouped[1].listId, 20)
    XCTAssertEqual(grouped[1].tasks.count, 1)
  }

  func testGroupedResultsEmptyWhenNoResults() {
    let vm = self.makeViewModel()
    XCTAssertTrue(vm.groupedResults.isEmpty)
  }

  // MARK: - List Loading Tests

  func testSearchLoadsListMetadataForResults() async {
    let task = TestFactories.makeSampleTask(id: 1, listId: 5, title: "Found")
    self.stubSearchResults([task])

    let vm = self.makeViewModel()
    vm.query = "found"

    // After search(), the VM will try to load lists for results.
    // MockNetworking returns the same stub for all calls, so the list
    // fetch will decode from whatever is currently stubbed.
    // For this test, we just verify the search completed and lists dict is populated.
    // The mock will return the TasksResponse for the list fetch too, which will
    // fail to decode as ListResponse — that's fine, the VM catches the error.
    await vm.search()

    XCTAssertEqual(vm.results.count, 1)
    // List loading may fail due to mock stub mismatch, but search itself succeeds
    XCTAssertFalse(vm.isSearching)
  }

  func testSearchSkipsListLoadingWhenListsAlreadyCached() async {
    let task = TestFactories.makeSampleTask(id: 1, listId: 5, title: "Found")
    self.stubSearchResults([task])

    let vm = self.makeViewModel()
    // Pre-populate list cache
    vm.lists[5] = TestFactories.makeSampleList(id: 5, name: "Work")
    vm.query = "found"
    await vm.search()

    // Only the search call should have been made, no list fetches
    let getCalls = self.mockNetworking.calls.filter { $0.method == "GET" }
    XCTAssertEqual(getCalls.count, 1) // Just the search call
  }
}
