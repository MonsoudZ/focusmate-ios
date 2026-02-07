import XCTest
@testable import focusmate

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
        mockNetworking = MockNetworking()
        apiClient = APIClient(tokenProvider: { nil }, networking: mockNetworking)
        taskService = TaskService(apiClient: apiClient, sideEffects: NoOpSideEffects())
        listService = ListService(apiClient: apiClient)
        tagService = TagService(apiClient: apiClient)
        inviteService = InviteService(apiClient: apiClient)
        friendService = FriendService(apiClient: apiClient)
        subtaskManager = SubtaskManager(taskService: taskService)
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
            taskService: taskService,
            listService: listService,
            tagService: tagService,
            inviteService: inviteService,
            friendService: friendService,
            subtaskManager: subtaskManager
        )
    }

    private func stubTasksResponse(_ tasks: [TaskDTO]) {
        let response = TasksResponse(tasks: tasks, tombstones: nil)
        mockNetworking.stubJSON(response)
    }

    // MARK: - Permission Tests

    func testIsOwnerWhenRoleIsOwner() {
        let list = TestFactories.makeSampleList(role: "owner")
        let vm = makeViewModel(list: list)
        XCTAssertTrue(vm.isOwner)
        XCTAssertFalse(vm.isEditor)
        XCTAssertFalse(vm.isViewer)
        XCTAssertTrue(vm.canEdit)
    }

    func testIsOwnerWhenRoleIsNil() {
        let list = TestFactories.makeSampleList(role: nil)
        let vm = makeViewModel(list: list)
        XCTAssertTrue(vm.isOwner)
        XCTAssertTrue(vm.canEdit)
    }

    func testIsEditorWhenRoleIsEditor() {
        let list = TestFactories.makeSampleList(role: "editor")
        let vm = makeViewModel(list: list)
        XCTAssertFalse(vm.isOwner)
        XCTAssertTrue(vm.isEditor)
        XCTAssertFalse(vm.isViewer)
        XCTAssertTrue(vm.canEdit)
    }

    func testIsViewerWhenRoleIsViewer() {
        let list = TestFactories.makeSampleList(role: "viewer")
        let vm = makeViewModel(list: list)
        XCTAssertFalse(vm.isOwner)
        XCTAssertFalse(vm.isEditor)
        XCTAssertTrue(vm.isViewer)
        XCTAssertFalse(vm.canEdit)
    }

    func testIsSharedList() {
        let ownedList = TestFactories.makeSampleList(role: "owner")
        let sharedList = TestFactories.makeSampleList(role: "editor")

        XCTAssertFalse(makeViewModel(list: ownedList).isSharedList)
        XCTAssertTrue(makeViewModel(list: sharedList).isSharedList)
    }

    func testRoleLabelAndIcon() {
        let ownerList = TestFactories.makeSampleList(role: "owner")
        let editorList = TestFactories.makeSampleList(role: "editor")
        let viewerList = TestFactories.makeSampleList(role: "viewer")

        XCTAssertEqual(makeViewModel(list: ownerList).roleLabel, "Owner")
        XCTAssertEqual(makeViewModel(list: editorList).roleLabel, "Editor")
        XCTAssertEqual(makeViewModel(list: viewerList).roleLabel, "Viewer")

        XCTAssertEqual(makeViewModel(list: ownerList).roleIcon, "crown.fill")
        XCTAssertEqual(makeViewModel(list: viewerList).roleIcon, "eye")
    }

    // MARK: - Load Tasks Tests

    func testLoadTasksFetchesFromService() async {
        let task1 = TestFactories.makeSampleTask(id: 1, title: "Task 1")
        let task2 = TestFactories.makeSampleTask(id: 2, title: "Task 2")
        stubTasksResponse([task1, task2])

        let vm = makeViewModel()
        await vm.loadTasks()

        XCTAssertEqual(vm.tasks.count, 2)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.error)
    }

    func testLoadTasksSetsErrorOnFailure() async {
        mockNetworking.stubbedError = APIError.serverError(500, "Server Error", nil)

        let vm = makeViewModel()
        await vm.loadTasks()

        XCTAssertTrue(vm.tasks.isEmpty)
        XCTAssertNotNil(vm.error)
        XCTAssertFalse(vm.isLoading)
    }

    // MARK: - Task Grouping Tests

    func testUrgentTasksFiltering() async {
        let urgentTask = TestFactories.makeSampleTask(id: 1, title: "Urgent", priority: TaskPriority.urgent.rawValue)
        let normalTask = TestFactories.makeSampleTask(id: 2, title: "Normal", priority: TaskPriority.none.rawValue)
        stubTasksResponse([urgentTask, normalTask])

        let vm = makeViewModel()
        await vm.loadTasks()

        XCTAssertEqual(vm.urgentTasks.count, 1)
        XCTAssertEqual(vm.urgentTasks.first?.title, "Urgent")
    }

    func testStarredTasksFiltering() async {
        let starredTask = TestFactories.makeSampleTask(id: 1, title: "Starred", starred: true)
        let normalTask = TestFactories.makeSampleTask(id: 2, title: "Normal", starred: false)
        stubTasksResponse([starredTask, normalTask])

        let vm = makeViewModel()
        await vm.loadTasks()

        XCTAssertEqual(vm.starredTasks.count, 1)
        XCTAssertEqual(vm.starredTasks.first?.title, "Starred")
    }

    func testCompletedTasksFiltering() async {
        let completedTask = TestFactories.makeSampleTask(id: 1, title: "Done", completedAt: Date().ISO8601Format())
        let incompleteTask = TestFactories.makeSampleTask(id: 2, title: "Pending")
        stubTasksResponse([completedTask, incompleteTask])

        let vm = makeViewModel()
        await vm.loadTasks()

        XCTAssertEqual(vm.completedTasks.count, 1)
        XCTAssertEqual(vm.completedTasks.first?.title, "Done")
    }

    func testNormalTasksExcludesUrgentStarredAndCompleted() async {
        let urgentTask = TestFactories.makeSampleTask(id: 1, title: "Urgent", priority: TaskPriority.urgent.rawValue)
        let starredTask = TestFactories.makeSampleTask(id: 2, title: "Starred", starred: true)
        let completedTask = TestFactories.makeSampleTask(id: 3, title: "Done", completedAt: Date().ISO8601Format())
        let normalTask = TestFactories.makeSampleTask(id: 4, title: "Normal")
        stubTasksResponse([urgentTask, starredTask, completedTask, normalTask])

        let vm = makeViewModel()
        await vm.loadTasks()

        XCTAssertEqual(vm.normalTasks.count, 1)
        XCTAssertEqual(vm.normalTasks.first?.title, "Normal")
    }

    // MARK: - Toggle Star Tests

    func testToggleStarUpdatesOptimistically() async {
        let task = TestFactories.makeSampleTask(id: 1, title: "Task", starred: false)
        stubTasksResponse([task])

        let vm = makeViewModel()
        await vm.loadTasks()

        // Stub update response
        mockNetworking.reset()
        mockNetworking.stubJSON(TestFactories.makeSampleTask(id: 1, title: "Task", starred: true))

        await vm.toggleStar(task)

        XCTAssertTrue(vm.tasks.first?.starred ?? false)
    }

    func testToggleStarDoesNothingForViewer() async {
        let list = TestFactories.makeSampleList(role: "viewer")
        let task = TestFactories.makeSampleTask(id: 1, title: "Task", starred: false)
        stubTasksResponse([task])

        let vm = makeViewModel(list: list)
        await vm.loadTasks()

        mockNetworking.reset()
        await vm.toggleStar(task)

        // No API call should be made
        XCTAssertTrue(mockNetworking.calls.isEmpty)
    }

    // MARK: - Toggle Complete Tests

    func testToggleCompleteMarksTaskCompleted() async {
        let task = TestFactories.makeSampleTask(id: 1, title: "Task")
        stubTasksResponse([task])

        let vm = makeViewModel()
        await vm.loadTasks()

        vm.markTaskCompleted(1)

        XCTAssertNotNil(vm.tasks.first?.completed_at)
    }

    func testToggleCompleteReopensCompletedTask() async {
        let completedTask = TestFactories.makeSampleTask(id: 1, title: "Task", completedAt: Date().ISO8601Format())
        stubTasksResponse([completedTask])

        let vm = makeViewModel()
        await vm.loadTasks()

        // Stub reopen response
        mockNetworking.reset()
        mockNetworking.stubJSON(TestFactories.makeSampleTask(id: 1, title: "Task"))

        await vm.toggleComplete(completedTask)

        let reopenCall = mockNetworking.calls.first { $0.path.contains("reopen") }
        XCTAssertNotNil(reopenCall)
    }

    // MARK: - Delete Task Tests

    func testDeleteTaskRemovesOptimistically() async {
        let task = TestFactories.makeSampleTask(id: 1, title: "To Delete")
        stubTasksResponse([task])

        let vm = makeViewModel()
        await vm.loadTasks()
        XCTAssertEqual(vm.tasks.count, 1)

        // Stub delete
        mockNetworking.reset()
        stubTasksResponse([])

        await vm.deleteTask(task)

        XCTAssertTrue(vm.tasks.isEmpty)
    }

    func testDeleteTaskRestoresOnError() async {
        let task = TestFactories.makeSampleTask(id: 1, title: "Cannot Delete")
        stubTasksResponse([task])

        let vm = makeViewModel()
        await vm.loadTasks()

        mockNetworking.stubbedError = APIError.serverError(500, "Delete failed", nil)

        await vm.deleteTask(task)

        // Task should be restored
        XCTAssertEqual(vm.tasks.count, 1)
        XCTAssertNotNil(vm.error)
    }

    func testDeleteTaskRespectsCanDeleteFlag() async {
        let task = TestFactories.makeSampleTask(id: 1, title: "No Delete", canDelete: false)
        stubTasksResponse([task])

        // Use viewer role which also can't edit
        let list = TestFactories.makeSampleList(role: "viewer")
        let vm = makeViewModel(list: list)
        await vm.loadTasks()

        mockNetworking.reset()
        await vm.deleteTask(task)

        // No API call should be made
        XCTAssertTrue(mockNetworking.calls.isEmpty)
    }

    // MARK: - Subtask Tests

    func testCreateSubtaskAddsToParentTask() async {
        let parentTask = TestFactories.makeSampleTask(id: 1, title: "Parent", subtasks: [])
        stubTasksResponse([parentTask])

        let vm = makeViewModel()
        await vm.loadTasks()

        // Stub subtask creation
        mockNetworking.reset()
        mockNetworking.stubJSON(TestFactories.makeSampleSubtask(id: 100, taskId: 1, title: "New Subtask"))

        await vm.createSubtask(parentTask: parentTask, title: "New Subtask")

        XCTAssertEqual(vm.tasks.first?.subtasks?.count, 1)
        XCTAssertEqual(vm.tasks.first?.subtasks?.first?.title, "New Subtask")
    }

    func testUpdateSubtaskUpdatesInPlace() async {
        let subtask = TestFactories.makeSampleSubtask(id: 100, taskId: 1, title: "Old Title")
        let parentTask = TestFactories.makeSampleTask(id: 1, title: "Parent", subtasks: [subtask])
        stubTasksResponse([parentTask])

        let vm = makeViewModel()
        await vm.loadTasks()

        // Stub subtask update
        mockNetworking.reset()
        mockNetworking.stubJSON(TestFactories.makeSampleSubtask(id: 100, taskId: 1, title: "New Title"))

        let editInfo = SubtaskEditInfo(subtask: subtask, parentTask: parentTask)
        await vm.updateSubtask(info: editInfo, title: "New Title")

        XCTAssertEqual(vm.tasks.first?.subtasks?.first?.title, "New Title")
    }

    // MARK: - Delete List Tests

    func testDeleteListCallsServiceAndDismisses() async {
        var dismissCalled = false
        let vm = makeViewModel()
        vm.onDismiss = { dismissCalled = true }

        // Stub delete
        stubTasksResponse([])

        await vm.deleteList()

        let deleteCall = mockNetworking.calls.first { $0.method == "DELETE" }
        XCTAssertNotNil(deleteCall)
        XCTAssertTrue(dismissCalled)
    }

    func testDeleteListSetsErrorOnFailure() async {
        mockNetworking.stubbedError = APIError.serverError(500, "Delete failed", nil)

        let vm = makeViewModel()
        await vm.deleteList()

        XCTAssertNotNil(vm.error)
    }

    // MARK: - UI State Tests

    func testDeleteConfirmationState() {
        let vm = makeViewModel()

        XCTAssertFalse(vm.showingDeleteConfirmation)
        vm.showingDeleteConfirmation = true
        XCTAssertTrue(vm.showingDeleteConfirmation)
    }

    func testNudgeMessageState() {
        let vm = makeViewModel()

        XCTAssertNil(vm.nudgeMessage)
        vm.nudgeMessage = "Nudge sent!"
        XCTAssertEqual(vm.nudgeMessage, "Nudge sent!")
    }
}
