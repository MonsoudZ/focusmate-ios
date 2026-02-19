@testable import focusmate
import XCTest

@MainActor
final class ListsViewModelTests: XCTestCase {
  private var mockNetworking: MockNetworking!
  private var apiClient: APIClient!
  private var listService: ListService!
  private var taskService: TaskService!
  private var tagService: TagService!
  private var inviteService: InviteService!
  private var friendService: FriendService!

  override func setUp() async throws {
    try await super.setUp()
    // Clear any cached responses from previous tests
    await ResponseCache.shared.invalidateAll()
    self.mockNetworking = MockNetworking()
    self.apiClient = APIClient(tokenProvider: { nil }, networking: self.mockNetworking)
    self.listService = ListService(apiClient: self.apiClient)
    self.taskService = TaskService(apiClient: self.apiClient, sideEffects: NoOpSideEffects())
    self.tagService = TagService(apiClient: self.apiClient)
    self.inviteService = InviteService(apiClient: self.apiClient)
    self.friendService = FriendService(apiClient: self.apiClient)
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

  private func makeViewModel() -> ListsViewModel {
    ListsViewModel(
      listService: self.listService,
      taskService: self.taskService,
      tagService: self.tagService,
      inviteService: self.inviteService,
      friendService: self.friendService
    )
  }

  private func stubListsResponse(_ lists: [ListDTO]) {
    let response = ListsResponse(lists: lists, tombstones: nil)
    self.mockNetworking.stubJSON(response)
  }

  // MARK: - loadLists Tests

  func testLoadListsFetchesFromService() async {
    let list1 = TestFactories.makeSampleList(id: 1, name: "Work")
    let list2 = TestFactories.makeSampleList(id: 2, name: "Personal")
    self.stubListsResponse([list1, list2])

    let vm = self.makeViewModel()
    await vm.loadLists()

    XCTAssertEqual(vm.lists.count, 2)
    XCTAssertEqual(vm.lists[0].name, "Work")
    XCTAssertEqual(vm.lists[1].name, "Personal")
    XCTAssertFalse(vm.isLoading)
    XCTAssertNil(vm.error)
  }

  func testLoadListsSetsLoadingState() async {
    self.stubListsResponse([])

    let vm = self.makeViewModel()

    // Before loading
    XCTAssertFalse(vm.isLoading)

    await vm.loadLists()

    // After loading
    XCTAssertFalse(vm.isLoading)
  }

  func testLoadListsSetsErrorOnFailure() async {
    self.mockNetworking.stubbedError = APIError.serverError(500, "Server Error", nil)

    let vm = self.makeViewModel()
    await vm.loadLists()

    XCTAssertTrue(vm.lists.isEmpty)
    XCTAssertNotNil(vm.error)
    XCTAssertFalse(vm.isLoading)
  }

  // MARK: - deleteList Tests

  func testDeleteListCallsServiceAndReloads() async {
    let list = TestFactories.makeSampleList(id: 5, name: "To Delete")
    self.stubListsResponse([list])

    let vm = self.makeViewModel()
    await vm.loadLists()

    XCTAssertEqual(vm.lists.count, 1)

    // Reset mock and stub empty response for delete
    self.mockNetworking.reset()
    self.stubListsResponse([])

    await vm.deleteList(list)

    // Verify delete was called
    let deleteCall = self.mockNetworking.calls.first { $0.method == "DELETE" }
    XCTAssertNotNil(deleteCall)
    XCTAssertTrue(deleteCall?.path.contains("5") ?? false)

    // List should be optimistically removed
    XCTAssertTrue(vm.lists.isEmpty)
  }

  func testDeleteListRestoresOnError() async {
    let list = TestFactories.makeSampleList(id: 5, name: "Cannot Delete")
    self.stubListsResponse([list])

    let vm = self.makeViewModel()
    await vm.loadLists()

    XCTAssertEqual(vm.lists.count, 1)

    // Set up error for delete
    self.mockNetworking.stubbedError = APIError.serverError(500, "Delete failed", nil)

    await vm.deleteList(list)

    // List should be restored after error
    XCTAssertEqual(vm.lists.count, 1)
    XCTAssertEqual(vm.lists.first?.name, "Cannot Delete")
    XCTAssertNotNil(vm.error)
  }

  // MARK: - Toggle and State Tests

  func testToggleAndStateProperties() async {
    await ResponseCache.shared.invalidateAll()
    let vm = self.makeViewModel()

    // Delete confirmation state
    let listToDelete = TestFactories.makeSampleList(id: 1, name: "Test")
    XCTAssertFalse(vm.showingDeleteConfirmation)
    XCTAssertNil(vm.listToDelete)
    vm.listToDelete = listToDelete
    vm.showingDeleteConfirmation = true
    XCTAssertTrue(vm.showingDeleteConfirmation)
    XCTAssertEqual(vm.listToDelete?.id, 1)
  }

  // MARK: - Empty State Tests

  func testEmptyListsState() async {
    self.stubListsResponse([])

    let vm = self.makeViewModel()
    await vm.loadLists()

    XCTAssertTrue(vm.lists.isEmpty)
    XCTAssertFalse(vm.isLoading)
    XCTAssertNil(vm.error)
  }
}
