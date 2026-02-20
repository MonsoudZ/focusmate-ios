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

  // MARK: - Initial State

  func testInitialState() {
    let vm = makeViewModel()

    XCTAssertEqual(vm.query, "")
    XCTAssertTrue(vm.results.isEmpty)
    XCTAssertFalse(vm.isSearching)
    XCTAssertFalse(vm.hasSearched)
    XCTAssertNil(vm.error)
    XCTAssertTrue(vm.lists.isEmpty)
  }

  func testInitialQuerySetsQuery() {
    let vm = makeViewModel(initialQuery: "groceries")

    XCTAssertEqual(vm.query, "groceries")
    XCTAssertFalse(vm.hasSearched)
  }

  // MARK: - Search

  func testSearchSuccess() async {
    let tasks = [
      TestFactories.makeSampleTask(id: 1, listId: 10, title: "Buy milk"),
      TestFactories.makeSampleTask(id: 2, listId: 10, title: "Buy eggs"),
    ]
    mockNetworking.stubJSON(TasksResponse(tasks: tasks, tombstones: nil))

    let vm = makeViewModel()
    vm.query = "Buy"
    await vm.search()

    XCTAssertEqual(vm.results.count, 2)
    XCTAssertTrue(vm.hasSearched)
    XCTAssertFalse(vm.isSearching)
    XCTAssertNil(vm.error)
  }

  func testSearchEmptyQueryDoesNothing() async {
    let vm = makeViewModel()
    vm.query = "   "
    await vm.search()

    XCTAssertTrue(vm.results.isEmpty)
    XCTAssertFalse(vm.hasSearched)
  }

  func testSearchTrimsWhitespace() async {
    mockNetworking.stubJSON(TasksResponse(tasks: [], tombstones: nil))

    let vm = makeViewModel()
    vm.query = "  hello  "
    await vm.search()

    // Verify the API was called with trimmed query
    let call = mockNetworking.lastCall
    XCTAssertEqual(call?.queryParameters["q"], "hello")
  }

  func testSearchTruncatesLongQuery() async {
    mockNetworking.stubJSON(TasksResponse(tasks: [], tombstones: nil))

    let vm = makeViewModel()
    vm.query = String(repeating: "a", count: 300)
    await vm.search()

    let call = mockNetworking.lastCall
    XCTAssertEqual(call?.queryParameters["q"]?.count, 255)
  }

  func testSearchError() async {
    mockNetworking.stubbedError = NSError(domain: "test", code: 500)

    let vm = makeViewModel()
    vm.query = "something"
    await vm.search()

    XCTAssertNotNil(vm.error)
    XCTAssertTrue(vm.results.isEmpty)
    XCTAssertTrue(vm.hasSearched)
    XCTAssertFalse(vm.isSearching)
  }

  func testSearchResetsErrorOnNewSearch() async {
    // First search fails
    mockNetworking.stubbedError = NSError(domain: "test", code: 500)
    let vm = makeViewModel()
    vm.query = "fail"
    await vm.search()
    XCTAssertNotNil(vm.error)

    // Second search succeeds
    mockNetworking.stubbedError = nil
    mockNetworking.stubJSON(TasksResponse(tasks: [], tombstones: nil))
    vm.query = "succeed"
    await vm.search()
    XCTAssertNil(vm.error)
  }

  // MARK: - searchIfNeeded

  func testSearchIfNeededWithInitialQuery() async {
    mockNetworking.stubJSON(TasksResponse(tasks: [
      TestFactories.makeSampleTask(id: 1, title: "Match"),
    ], tombstones: nil))

    let vm = makeViewModel(initialQuery: "Match")
    await vm.searchIfNeeded()

    XCTAssertEqual(vm.results.count, 1)
    XCTAssertTrue(vm.hasSearched)
  }

  func testSearchIfNeededWithoutInitialQueryDoesNothing() async {
    let vm = makeViewModel()
    await vm.searchIfNeeded()

    XCTAssertFalse(vm.hasSearched)
    XCTAssertTrue(mockNetworking.calls.isEmpty)
  }

  func testSearchIfNeededOnlySearchesOnce() async {
    mockNetworking.stubJSON(TasksResponse(tasks: [], tombstones: nil))

    let vm = makeViewModel(initialQuery: "once")
    await vm.searchIfNeeded()
    let callCount = mockNetworking.calls.count

    await vm.searchIfNeeded()
    XCTAssertEqual(mockNetworking.calls.count, callCount, "Should not search again after first search")
  }

  // MARK: - clearSearch

  func testClearSearch() async {
    mockNetworking.stubJSON(TasksResponse(tasks: [
      TestFactories.makeSampleTask(id: 1, title: "Task"),
    ], tombstones: nil))

    let vm = makeViewModel()
    vm.query = "Task"
    await vm.search()
    XCTAssertFalse(vm.results.isEmpty)

    vm.clearSearch()

    XCTAssertEqual(vm.query, "")
    XCTAssertTrue(vm.results.isEmpty)
    XCTAssertFalse(vm.hasSearched)
  }

  // MARK: - groupedResults

  func testGroupedResultsSortsByListId() async {
    let tasks = [
      TestFactories.makeSampleTask(id: 1, listId: 30, title: "Task A"),
      TestFactories.makeSampleTask(id: 2, listId: 10, title: "Task B"),
      TestFactories.makeSampleTask(id: 3, listId: 20, title: "Task C"),
      TestFactories.makeSampleTask(id: 4, listId: 10, title: "Task D"),
    ]
    mockNetworking.stubJSON(TasksResponse(tasks: tasks, tombstones: nil))

    let vm = makeViewModel()
    vm.query = "Task"
    await vm.search()

    let grouped = vm.groupedResults
    XCTAssertEqual(grouped.count, 3)
    XCTAssertEqual(grouped[0].listId, 10)
    XCTAssertEqual(grouped[0].tasks.count, 2)
    XCTAssertEqual(grouped[1].listId, 20)
    XCTAssertEqual(grouped[2].listId, 30)
  }

  func testGroupedResultsEmptyWhenNoResults() {
    let vm = makeViewModel()
    XCTAssertTrue(vm.groupedResults.isEmpty)
  }

  // MARK: - List Loading

  func testSearchLoadsListMetadata() async {
    let tasks = [
      TestFactories.makeSampleTask(id: 1, listId: 5, title: "Task"),
    ]
    mockNetworking.stubJSON(TasksResponse(tasks: tasks, tombstones: nil))

    let vm = makeViewModel()
    vm.query = "Task"
    await vm.search()

    // After search, lists should be populated for the result's list_id.
    // MockNetworking returns the same stub for all calls, but the list
    // loading path uses fetchList(id:) which goes through the same mock.
    // The key assertion: the VM attempted to load list metadata.
    XCTAssertTrue(mockNetworking.calls.count > 1, "Should make additional calls to load list metadata")
  }

  func testSearchSkipsAlreadyCachedLists() async {
    let tasks = [
      TestFactories.makeSampleTask(id: 1, listId: 5, title: "Task"),
    ]

    let vm = makeViewModel()
    // Pre-populate the list cache
    vm.lists[5] = TestFactories.makeSampleList(id: 5, name: "Cached List")

    mockNetworking.stubJSON(TasksResponse(tasks: tasks, tombstones: nil))
    vm.query = "Task"
    await vm.search()

    // Should only have the search call, no list fetch calls
    XCTAssertEqual(mockNetworking.calls.count, 1, "Should not fetch already-cached lists")
  }
}
