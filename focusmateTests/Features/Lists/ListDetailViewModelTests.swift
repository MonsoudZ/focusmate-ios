@testable import focusmate
import XCTest

@MainActor
final class ListDetailViewModelTests: XCTestCase {
  private var mockNetworking: MockNetworking!
  private var apiClient: APIClient!
  private var taskService: TaskService!
  private var listService: ListService!
  private var tagService: TagService!
  private var inviteService: InviteService!
  private var friendService: FriendService!
  private var subtaskManager: SubtaskManager!

  override func setUp() async throws {
    try await super.setUp()
    await ResponseCache.shared.invalidateAll()
    self.mockNetworking = MockNetworking()
    self.apiClient = APIClient(tokenProvider: { nil }, networking: self.mockNetworking)
    self.taskService = TaskService(apiClient: self.apiClient, sideEffects: NoOpSideEffects())
    self.listService = ListService(apiClient: self.apiClient)
    self.tagService = TagService(apiClient: self.apiClient)
    self.inviteService = InviteService(apiClient: self.apiClient)
    self.friendService = FriendService(apiClient: self.apiClient)
    self.subtaskManager = SubtaskManager(taskService: self.taskService)
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

  private func makeViewModel(list: ListDTO? = nil) -> ListDetailViewModel {
    ListDetailViewModel(
      list: list ?? TestFactories.makeSampleList(),
      taskService: self.taskService,
      listService: self.listService,
      tagService: self.tagService,
      inviteService: self.inviteService,
      friendService: self.friendService,
      subtaskManager: self.subtaskManager
    )
  }

  private func stubTasksResponse(_ tasks: [TaskDTO]) {
    let response = TasksResponse(tasks: tasks, tombstones: nil)
    self.mockNetworking.stubJSON(response)
  }

  // MARK: - Permission Tests

  func testIsOwnerWhenRoleIsOwner() {
    let list = TestFactories.makeSampleList(role: "owner")
    let vm = self.makeViewModel(list: list)
    XCTAssertTrue(vm.isOwner)
    XCTAssertFalse(vm.isEditor)
    XCTAssertFalse(vm.isViewer)
    XCTAssertTrue(vm.canEdit)
  }

  func testIsOwnerWhenRoleIsNil() {
    let list = TestFactories.makeSampleList(role: nil)
    let vm = self.makeViewModel(list: list)
    XCTAssertTrue(vm.isOwner)
    XCTAssertTrue(vm.canEdit)
  }

  func testIsEditorWhenRoleIsEditor() {
    let list = TestFactories.makeSampleList(role: "editor")
    let vm = self.makeViewModel(list: list)
    XCTAssertFalse(vm.isOwner)
    XCTAssertTrue(vm.isEditor)
    XCTAssertFalse(vm.isViewer)
    XCTAssertTrue(vm.canEdit)
  }

  func testIsViewerWhenRoleIsViewer() {
    let list = TestFactories.makeSampleList(role: "viewer")
    let vm = self.makeViewModel(list: list)
    XCTAssertFalse(vm.isOwner)
    XCTAssertFalse(vm.isEditor)
    XCTAssertTrue(vm.isViewer)
    XCTAssertFalse(vm.canEdit)
  }

  func testIsSharedList() {
    let twoMembers = [
      ListMemberDTO(id: 1, name: "Me", email: "me@test.com", role: "owner"),
      ListMemberDTO(id: 2, name: "Friend", email: "f@test.com", role: "editor"),
    ]

    // Personal lists (no role, no members) — not shared
    let personalList = TestFactories.makeSampleList(role: nil)
    XCTAssertFalse(self.makeViewModel(list: personalList).isSharedList)

    // Collaborative list with only one member — not shared (nobody to nudge)
    let soloShared = TestFactories.makeSampleList(role: "owner", members: [twoMembers[0]])
    XCTAssertFalse(self.makeViewModel(list: soloShared).isSharedList)

    // Collaborative list with nil members (not yet fetched) — not shared
    let nilMembers = TestFactories.makeSampleList(role: "owner", members: nil)
    XCTAssertFalse(self.makeViewModel(list: nilMembers).isSharedList)

    // Multiple members — shared
    let sharedAsOwner = TestFactories.makeSampleList(role: "owner", members: twoMembers)
    let sharedAsEditor = TestFactories.makeSampleList(role: "editor", members: twoMembers)
    XCTAssertTrue(self.makeViewModel(list: sharedAsOwner).isSharedList)
    XCTAssertTrue(self.makeViewModel(list: sharedAsEditor).isSharedList)
  }

  func testRoleLabelAndIcon() {
    let ownerList = TestFactories.makeSampleList(role: "owner")
    let editorList = TestFactories.makeSampleList(role: "editor")
    let viewerList = TestFactories.makeSampleList(role: "viewer")

    XCTAssertEqual(self.makeViewModel(list: ownerList).roleLabel, "Owner")
    XCTAssertEqual(self.makeViewModel(list: editorList).roleLabel, "Editor")
    XCTAssertEqual(self.makeViewModel(list: viewerList).roleLabel, "Viewer")

    XCTAssertEqual(self.makeViewModel(list: ownerList).roleIcon, "crown.fill")
    XCTAssertEqual(self.makeViewModel(list: viewerList).roleIcon, "eye")
  }

  // MARK: - Load Tasks Tests

  func testLoadTasksFetchesFromService() async {
    let task1 = TestFactories.makeSampleTask(id: 1, title: "Task 1")
    let task2 = TestFactories.makeSampleTask(id: 2, title: "Task 2")
    self.stubTasksResponse([task1, task2])

    let vm = self.makeViewModel()
    await vm.loadTasks()

    XCTAssertEqual(vm.tasks.count, 2)
    XCTAssertFalse(vm.isLoading)
    XCTAssertNil(vm.error)
  }

  func testLoadTasksSetsErrorOnFailure() async {
    self.mockNetworking.stubbedError = APIError.serverError(500, "Server Error", nil)

    let vm = self.makeViewModel()
    await vm.loadTasks()

    XCTAssertTrue(vm.tasks.isEmpty)
    XCTAssertNotNil(vm.error)
    XCTAssertFalse(vm.isLoading)
  }

  // MARK: - Task Grouping Tests

  func testUrgentTasksFiltering() async {
    let urgentTask = TestFactories.makeSampleTask(id: 1, title: "Urgent", priority: TaskPriority.urgent.rawValue)
    let normalTask = TestFactories.makeSampleTask(id: 2, title: "Normal", priority: TaskPriority.none.rawValue)
    self.stubTasksResponse([urgentTask, normalTask])

    let vm = self.makeViewModel()
    await vm.loadTasks()

    XCTAssertEqual(vm.urgentTasks.count, 1)
    XCTAssertEqual(vm.urgentTasks.first?.title, "Urgent")
  }

  func testStarredTasksFiltering() async {
    let starredTask = TestFactories.makeSampleTask(id: 1, title: "Starred", starred: true)
    let normalTask = TestFactories.makeSampleTask(id: 2, title: "Normal", starred: false)
    self.stubTasksResponse([starredTask, normalTask])

    let vm = self.makeViewModel()
    await vm.loadTasks()

    XCTAssertEqual(vm.starredTasks.count, 1)
    XCTAssertEqual(vm.starredTasks.first?.title, "Starred")
  }

  func testCompletedTasksFiltering() async {
    let completedTask = TestFactories.makeSampleTask(id: 1, title: "Done", completedAt: Date().ISO8601Format())
    let incompleteTask = TestFactories.makeSampleTask(id: 2, title: "Pending")
    self.stubTasksResponse([completedTask, incompleteTask])

    let vm = self.makeViewModel()
    await vm.loadTasks()

    XCTAssertEqual(vm.completedTasks.count, 1)
    XCTAssertEqual(vm.completedTasks.first?.title, "Done")
  }

  func testNormalTasksExcludesUrgentStarredAndCompleted() async {
    let urgentTask = TestFactories.makeSampleTask(id: 1, title: "Urgent", priority: TaskPriority.urgent.rawValue)
    let starredTask = TestFactories.makeSampleTask(id: 2, title: "Starred", starred: true)
    let completedTask = TestFactories.makeSampleTask(id: 3, title: "Done", completedAt: Date().ISO8601Format())
    let normalTask = TestFactories.makeSampleTask(id: 4, title: "Normal")
    self.stubTasksResponse([urgentTask, starredTask, completedTask, normalTask])

    let vm = self.makeViewModel()
    await vm.loadTasks()

    XCTAssertEqual(vm.normalTasks.count, 1)
    XCTAssertEqual(vm.normalTasks.first?.title, "Normal")
  }

  // MARK: - Toggle Star Tests

  func testToggleStarUpdatesOptimistically() async {
    let task = TestFactories.makeSampleTask(id: 1, title: "Task", starred: false)
    self.stubTasksResponse([task])

    let vm = self.makeViewModel()
    await vm.loadTasks()

    // Stub update response
    self.mockNetworking.reset()
    self.mockNetworking.stubJSON(SingleTaskResponse(task: TestFactories.makeSampleTask(
      id: 1,
      title: "Task",
      starred: true
    )))

    await vm.toggleStar(task)

    XCTAssertTrue(vm.tasks.first?.starred ?? false)
  }

  func testToggleStarDoesNothingForViewer() async {
    let list = TestFactories.makeSampleList(role: "viewer")
    let task = TestFactories.makeSampleTask(id: 1, title: "Task", starred: false)
    self.stubTasksResponse([task])

    let vm = self.makeViewModel(list: list)
    await vm.loadTasks()

    self.mockNetworking.reset()
    await vm.toggleStar(task)

    // No API call should be made
    XCTAssertTrue(self.mockNetworking.calls.isEmpty)
  }

  // MARK: - Toggle Complete Tests

  func testToggleCompleteMarksTaskCompleted() async {
    let task = TestFactories.makeSampleTask(id: 1, title: "Task")
    self.stubTasksResponse([task])

    let vm = self.makeViewModel()
    await vm.loadTasks()

    vm.markTaskCompleted(1)

    XCTAssertNotNil(vm.tasks.first?.completed_at)
  }

  func testToggleCompleteReopensCompletedTask() async {
    let completedTask = TestFactories.makeSampleTask(id: 1, title: "Task", completedAt: Date().ISO8601Format())
    self.stubTasksResponse([completedTask])

    let vm = self.makeViewModel()
    await vm.loadTasks()

    // Stub reopen response
    self.mockNetworking.reset()
    self.mockNetworking.stubJSON(TestFactories.makeSampleTask(id: 1, title: "Task"))

    await vm.toggleComplete(completedTask)

    let reopenCall = self.mockNetworking.calls.first { $0.path.contains("reopen") }
    XCTAssertNotNil(reopenCall)
  }

  // MARK: - Delete Task Tests

  func testDeleteTaskRemovesOptimistically() async {
    let task = TestFactories.makeSampleTask(id: 1, title: "To Delete")
    self.stubTasksResponse([task])

    let vm = self.makeViewModel()
    await vm.loadTasks()
    XCTAssertEqual(vm.tasks.count, 1)

    // Stub delete
    self.mockNetworking.reset()
    self.stubTasksResponse([])

    await vm.deleteTask(task)

    XCTAssertTrue(vm.tasks.isEmpty)
  }

  func testDeleteTaskRestoresOnError() async {
    let task = TestFactories.makeSampleTask(id: 1, title: "Cannot Delete")
    self.stubTasksResponse([task])

    let vm = self.makeViewModel()
    await vm.loadTasks()

    self.mockNetworking.stubbedError = APIError.serverError(500, "Delete failed", nil)

    await vm.deleteTask(task)

    // Task should be restored
    XCTAssertEqual(vm.tasks.count, 1)
    XCTAssertNotNil(vm.error)
  }

  func testDeleteTaskRespectsCanDeleteFlag() async {
    let task = TestFactories.makeSampleTask(id: 1, title: "No Delete", canDelete: false)
    self.stubTasksResponse([task])

    // Use viewer role which also can't edit
    let list = TestFactories.makeSampleList(role: "viewer")
    let vm = self.makeViewModel(list: list)
    await vm.loadTasks()

    self.mockNetworking.reset()
    await vm.deleteTask(task)

    // No API call should be made
    XCTAssertTrue(self.mockNetworking.calls.isEmpty)
  }

  // MARK: - Subtask Tests

  func testCreateSubtaskAddsToParentTask() async {
    let parentTask = TestFactories.makeSampleTask(id: 1, title: "Parent", subtasks: [])
    self.stubTasksResponse([parentTask])

    let vm = self.makeViewModel()
    await vm.loadTasks()

    // Stub subtask creation
    self.mockNetworking.reset()
    self.mockNetworking.stubJSON(SubtaskResponse(subtask: TestFactories.makeSampleSubtask(
      id: 100,
      parentTaskId: 1,
      title: "New Subtask"
    )))

    await vm.createSubtask(parentTask: parentTask, title: "New Subtask")

    XCTAssertEqual(vm.tasks.first?.subtasks?.count, 1)
    XCTAssertEqual(vm.tasks.first?.subtasks?.first?.title, "New Subtask")
  }

  func testUpdateSubtaskUpdatesInPlace() async {
    let subtask = TestFactories.makeSampleSubtask(id: 100, parentTaskId: 1, title: "Old Title")
    let parentTask = TestFactories.makeSampleTask(id: 1, title: "Parent", subtasks: [subtask])
    self.stubTasksResponse([parentTask])

    let vm = self.makeViewModel()
    await vm.loadTasks()

    // Stub subtask update
    self.mockNetworking.reset()
    self.mockNetworking.stubJSON(SubtaskResponse(subtask: TestFactories.makeSampleSubtask(
      id: 100,
      parentTaskId: 1,
      title: "New Title"
    )))

    let editInfo = SubtaskEditInfo(subtask: subtask, parentTask: parentTask)
    await vm.updateSubtask(info: editInfo, title: "New Title")

    XCTAssertEqual(vm.tasks.first?.subtasks?.first?.title, "New Title")
  }

  // MARK: - Delete List Tests

  func testDeleteListCallsServiceAndDismisses() async {
    var dismissCalled = false
    let vm = self.makeViewModel()
    vm.onDismiss = { dismissCalled = true }

    // Stub delete
    self.stubTasksResponse([])

    await vm.deleteList()

    let deleteCall = self.mockNetworking.calls.first { $0.method == "DELETE" }
    XCTAssertNotNil(deleteCall)
    XCTAssertTrue(dismissCalled)
  }

  func testDeleteListSetsErrorOnFailure() async {
    self.mockNetworking.stubbedError = APIError.serverError(500, "Delete failed", nil)

    let vm = self.makeViewModel()
    await vm.deleteList()

    XCTAssertNotNil(vm.error)
  }

  // MARK: - UI State Tests

  func testDeleteConfirmationState() {
    let vm = self.makeViewModel()

    XCTAssertFalse(vm.showingDeleteConfirmation)
    vm.showingDeleteConfirmation = true
    XCTAssertTrue(vm.showingDeleteConfirmation)
  }

  func testNudgeMessageState() {
    let vm = self.makeViewModel()

    XCTAssertNil(vm.nudgeMessage)
    vm.nudgeMessage = "Nudge sent!"
    XCTAssertEqual(vm.nudgeMessage, "Nudge sent!")
  }
}
