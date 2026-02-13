import XCTest
@testable import focusmate

@MainActor
final class TodayViewModelTests: XCTestCase {

    private var mockNetworking: MockNetworking!
    private var apiClient: APIClient!
    private var taskService: TaskService!
    private var listService: ListService!
    private var tagService: TagService!
    private var subtaskManager: SubtaskManager!

    override func setUp() async throws {
        try await super.setUp()
        // Clear any cached responses from previous tests
        await ResponseCache.shared.invalidateAll()
        mockNetworking = MockNetworking()
        apiClient = APIClient(tokenProvider: { nil }, networking: mockNetworking)
        taskService = TaskService(apiClient: apiClient, sideEffects: NoOpSideEffects())
        listService = ListService(apiClient: apiClient)
        tagService = TagService(apiClient: apiClient)
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

    private func makeViewModel() -> TodayViewModel {
        let vm = TodayViewModel(
            taskService: taskService,
            listService: listService,
            tagService: tagService,
            apiClient: apiClient,
            subtaskManager: subtaskManager
        )
        vm.initializeServiceIfNeeded()
        return vm
    }

    private func stubTodayResponse(
        overdue: [TaskDTO] = [],
        dueToday: [TaskDTO] = [],
        completedToday: [TaskDTO] = [],
        stats: TodayStats? = nil
    ) {
        let response = TodayResponse(
            overdue: overdue,
            due_today: dueToday,
            completed_today: completedToday,
            stats: stats ?? TodayStats(
                overdue_count: overdue.count,
                due_today_count: dueToday.count,
                completed_today_count: completedToday.count
            ),
            streak: nil
        )
        mockNetworking.stubJSON(response)
    }

    // MARK: - loadToday Tests

    func testLoadTodaySetsDataOnSuccess() async {
        let task1 = TestFactories.makeSampleTask(
            id: 1, title: "Overdue Task",
            dueAt: TestFactories.isoString(daysFromNow: -1, hour: 10, minute: 0),
            overdue: true
        )
        let task2 = TestFactories.makeSampleTask(
            id: 2, title: "Due Today Task",
            dueAt: TestFactories.isoString(daysFromNow: 0, hour: 14, minute: 0)
        )
        let task3 = TestFactories.makeSampleTask(
            id: 3,
            title: "Completed Task",
            completedAt: Date().ISO8601Format()
        )

        stubTodayResponse(
            overdue: [task1],
            dueToday: [task2],
            completedToday: [task3]
        )

        let vm = makeViewModel()
        await vm.loadToday()

        XCTAssertNotNil(vm.todayData)
        XCTAssertEqual(vm.todayData?.overdue.count, 1)
        XCTAssertEqual(vm.todayData?.due_today.count, 1)
        XCTAssertEqual(vm.todayData?.completed_today.count, 1)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.error)
    }

    func testLoadTodaySetsErrorOnFailure() async {
        // Ensure no cached data interferes with error test
        await ResponseCache.shared.invalidateAll()
        mockNetworking.stubbedError = APIError.serverError(500, "Server Error", nil)

        let vm = makeViewModel()
        await vm.loadToday()

        XCTAssertNil(vm.todayData)
        XCTAssertNotNil(vm.error)
        XCTAssertFalse(vm.isLoading)
    }

    func testLoadTodayUpdatesOverdueCount() async {
        let overdueTask = TestFactories.makeSampleTask(
            id: 1, title: "Overdue",
            dueAt: TestFactories.isoString(daysFromNow: -1, hour: 10, minute: 0),
            overdue: true
        )
        stubTodayResponse(
            overdue: [overdueTask],
            stats: TodayStats(overdue_count: 1, due_today_count: 0, completed_today_count: 0)
        )

        var receivedCount: Int?
        let vm = makeViewModel()
        vm.onOverdueCountChange = { count in
            receivedCount = count
        }

        await vm.loadToday()

        XCTAssertEqual(receivedCount, 1)
    }

    // MARK: - toggleComplete Tests

    func testToggleCompleteReopensCompletedTask() async {
        let completedTask = TestFactories.makeSampleTask(
            id: 1,
            listId: 10,
            title: "Completed Task",
            completedAt: Date().ISO8601Format()
        )

        // Stub reopen response
        mockNetworking.stubJSON(SingleTaskResponse(task: TestFactories.makeSampleTask(id: 1, listId: 10, title: "Reopened Task")))

        let vm = makeViewModel()

        // First stub a today response for the loadToday after reopen
        stubTodayResponse(dueToday: [TestFactories.makeSampleTask(id: 1, title: "Reopened Task")])

        await vm.toggleComplete(completedTask)

        // Verify the reopen endpoint was called
        let reopenCall = mockNetworking.calls.first { $0.path.contains("reopen") }
        XCTAssertNotNil(reopenCall)
        XCTAssertEqual(reopenCall?.method, "PATCH")
    }

    // MARK: - deleteTask Tests

    func testDeleteTaskRemovesAndReloads() async {
        let task = TestFactories.makeSampleTask(id: 5, listId: 10, title: "To Delete")

        // Stub delete (returns empty) and then today response
        stubTodayResponse()

        let vm = makeViewModel()
        await vm.deleteTask(task)

        let deleteCall = mockNetworking.calls.first { $0.method == "DELETE" }
        XCTAssertNotNil(deleteCall)
        XCTAssertTrue(deleteCall?.path.contains("5") ?? false)
    }

    // MARK: - Computed Properties Tests

    func testComputedPropertiesCalculateCorrectly() async {
        let overdue1 = TestFactories.makeSampleTask(
            id: 1, title: "Overdue 1",
            dueAt: TestFactories.isoString(daysFromNow: -1, hour: 10, minute: 0),
            overdue: true
        )
        let dueToday1 = TestFactories.makeSampleTask(
            id: 2, title: "Due Today 1",
            dueAt: TestFactories.isoString(daysFromNow: 0, hour: 10, minute: 0)
        )
        let dueToday2 = TestFactories.makeSampleTask(
            id: 3, title: "Due Today 2",
            dueAt: TestFactories.isoString(daysFromNow: 0, hour: 14, minute: 0)
        )
        let completed1 = TestFactories.makeSampleTask(
            id: 4,
            title: "Completed 1",
            completedAt: Date().ISO8601Format()
        )
        let completed2 = TestFactories.makeSampleTask(
            id: 5,
            title: "Completed 2",
            completedAt: Date().ISO8601Format()
        )

        stubTodayResponse(
            overdue: [overdue1],
            dueToday: [dueToday1, dueToday2],
            completedToday: [completed1, completed2]
        )

        let vm = makeViewModel()
        await vm.loadToday()

        XCTAssertEqual(vm.totalTasks, 5)
        XCTAssertEqual(vm.completedCount, 2)
        XCTAssertEqual(vm.progress, 0.4, accuracy: 0.01)
        XCTAssertFalse(vm.isAllComplete)
    }

    func testIsAllCompleteWhenNoDueTasks() async {
        let completed1 = TestFactories.makeSampleTask(
            id: 1,
            title: "Completed 1",
            completedAt: Date().ISO8601Format()
        )

        stubTodayResponse(
            overdue: [],
            dueToday: [],
            completedToday: [completed1]
        )

        let vm = makeViewModel()
        await vm.loadToday()

        XCTAssertTrue(vm.isAllComplete)
    }

    // MARK: - groupedTasks Tests

    func testGroupedTasksSortsCorrectly() async {
        // Anytime task (midnight)
        let anytimeTask = TestFactories.makeSampleTask(
            id: 1,
            title: "Anytime",
            dueAt: TestFactories.midnightISOString(daysFromNow: 0)
        )

        // Morning task (9 AM)
        let morningTask = TestFactories.makeSampleTask(
            id: 2,
            title: "Morning",
            dueAt: TestFactories.isoString(daysFromNow: 0, hour: 9, minute: 0)
        )

        // Afternoon task (14:00)
        let afternoonTask = TestFactories.makeSampleTask(
            id: 3,
            title: "Afternoon",
            dueAt: TestFactories.isoString(daysFromNow: 0, hour: 14, minute: 0)
        )

        // Evening task (18:00)
        let eveningTask = TestFactories.makeSampleTask(
            id: 4,
            title: "Evening",
            dueAt: TestFactories.isoString(daysFromNow: 0, hour: 18, minute: 0)
        )

        stubTodayResponse(
            dueToday: [anytimeTask, morningTask, afternoonTask, eveningTask]
        )

        let vm = makeViewModel()
        await vm.loadToday()

        let grouped = vm.groupedTasks
        XCTAssertEqual(grouped.anytime.count, 1)
        XCTAssertEqual(grouped.anytime.first?.title, "Anytime")
        XCTAssertEqual(grouped.morning.count, 1)
        XCTAssertEqual(grouped.morning.first?.title, "Morning")
        XCTAssertEqual(grouped.afternoon.count, 1)
        XCTAssertEqual(grouped.afternoon.first?.title, "Afternoon")
        XCTAssertEqual(grouped.evening.count, 1)
        XCTAssertEqual(grouped.evening.first?.title, "Evening")
    }

    func testGroupedTasksWithNoDueDate() async {
        let taskNoDue = TestFactories.makeSampleTask(id: 1, title: "No Due Date", dueAt: nil)

        stubTodayResponse(dueToday: [taskNoDue])

        let vm = makeViewModel()
        await vm.loadToday()

        let grouped = vm.groupedTasks
        XCTAssertEqual(grouped.anytime.count, 1)
        XCTAssertEqual(grouped.anytime.first?.title, "No Due Date")
    }

    // MARK: - Progress Edge Cases

    func testProgressIsZeroWhenNoTasks() async {
        // Ensure no cached data interferes
        await ResponseCache.shared.invalidateAll()
        stubTodayResponse()

        let vm = makeViewModel()
        await vm.loadToday()

        XCTAssertEqual(vm.progress, 0)
        XCTAssertEqual(vm.totalTasks, 0)
    }

    // MARK: - Timezone Guard Tests
    //
    // The guard only REMOVES tasks whose calendar day is clearly wrong
    // (future tasks that leaked in from a timezone mismatch).  It does NOT
    // re-bucket between overdue ↔ due_today — the server owns that split.

    func testGuardDropsTomorrowTaskFromDueToday() async {
        // Server's stale timezone included a tomorrow task in due_today
        let tomorrowTask = TestFactories.makeSampleTask(
            id: 1, title: "Tomorrow Task",
            dueAt: TestFactories.isoString(daysFromNow: 1, hour: 10, minute: 0)
        )

        stubTodayResponse(dueToday: [tomorrowTask])

        let vm = makeViewModel()
        await vm.loadToday()

        XCTAssertEqual(vm.todayData?.due_today.count, 0, "Tomorrow's task should be removed from due_today")
        XCTAssertEqual(vm.todayData?.overdue.count, 0, "Tomorrow's task should not appear in overdue")
    }

    func testGuardDropsFutureTaskFromOverdue() async {
        // A future task should never be in overdue
        let futureTask = TestFactories.makeSampleTask(
            id: 1, title: "Future Task",
            dueAt: TestFactories.isoString(daysFromNow: 2, hour: 10, minute: 0)
        )

        stubTodayResponse(overdue: [futureTask])

        let vm = makeViewModel()
        await vm.loadToday()

        XCTAssertEqual(vm.todayData?.overdue.count, 0, "Future task should be removed from overdue")
    }

    func testGuardKeepsTodayTaskInDueToday() async {
        let todayTask = TestFactories.makeSampleTask(
            id: 1, title: "Today Task",
            dueAt: TestFactories.isoString(daysFromNow: 0, hour: 23, minute: 59)
        )

        stubTodayResponse(dueToday: [todayTask])

        let vm = makeViewModel()
        await vm.loadToday()

        XCTAssertEqual(vm.todayData?.due_today.count, 1, "Today's task should remain in due_today")
        XCTAssertEqual(vm.todayData?.due_today.first?.id, 1)
    }

    func testGuardKeepsYesterdayTaskInServerBucket() async {
        // Server placed a yesterday task in due_today — guard does NOT
        // second-guess the server's bucketing, only removes future leaks.
        let yesterdayTask = TestFactories.makeSampleTask(
            id: 1, title: "Yesterday Task",
            dueAt: TestFactories.isoString(daysFromNow: -1, hour: 14, minute: 0)
        )

        stubTodayResponse(dueToday: [yesterdayTask])

        let vm = makeViewModel()
        await vm.loadToday()

        XCTAssertEqual(vm.todayData?.due_today.count, 1, "Past tasks stay in server's bucket — guard only strips future leaks")
    }

    func testGuardPreservesOverdueBucket() async {
        // Server says overdue — client doesn't move it to due_today
        let overdueTask = TestFactories.makeSampleTask(
            id: 1, title: "Overdue",
            dueAt: TestFactories.isoString(daysFromNow: -1, hour: 10, minute: 0),
            overdue: true
        )

        stubTodayResponse(overdue: [overdueTask])

        let vm = makeViewModel()
        await vm.loadToday()

        XCTAssertEqual(vm.todayData?.overdue.count, 1, "Overdue tasks stay in overdue — server's call")
        XCTAssertEqual(vm.todayData?.due_today.count, 0)
    }

    func testGuardTrustsCompletedTodayFromServer() async {
        // Completed tasks pass through untouched regardless of due date
        let completedTask = TestFactories.makeSampleTask(
            id: 1, title: "Done",
            dueAt: TestFactories.isoString(daysFromNow: -2, hour: 10, minute: 0),
            completedAt: Date().ISO8601Format()
        )

        stubTodayResponse(completedToday: [completedTask])

        let vm = makeViewModel()
        await vm.loadToday()

        XCTAssertEqual(vm.todayData?.completed_today.count, 1, "Completed tasks should be trusted from server")
    }

    func testGuardRecalculatesStatsOnRemoval() async {
        // Server says 2 due_today — but one is tomorrow
        let tomorrowTask = TestFactories.makeSampleTask(
            id: 1, title: "Tomorrow",
            dueAt: TestFactories.isoString(daysFromNow: 1, hour: 14, minute: 0)
        )
        let todayTask = TestFactories.makeSampleTask(
            id: 2, title: "Today",
            dueAt: TestFactories.isoString(daysFromNow: 0, hour: 23, minute: 0)
        )

        stubTodayResponse(
            dueToday: [tomorrowTask, todayTask],
            stats: TodayStats(overdue_count: 0, due_today_count: 2, completed_today_count: 0)
        )

        let vm = makeViewModel()
        await vm.loadToday()

        XCTAssertEqual(vm.todayData?.stats?.due_today_count, 1, "Stats should reflect removal of tomorrow task")
    }

    func testGuardSkipsRebuildWhenNothingRemoved() async {
        // All tasks belong to today — guard should return the original response
        let task1 = TestFactories.makeSampleTask(
            id: 1, title: "Task 1",
            dueAt: TestFactories.isoString(daysFromNow: 0, hour: 23, minute: 0)
        )
        let task2 = TestFactories.makeSampleTask(
            id: 2, title: "Task 2",
            dueAt: TestFactories.midnightISOString(daysFromNow: 0)
        )

        stubTodayResponse(dueToday: [task1, task2])

        let vm = makeViewModel()
        await vm.loadToday()

        XCTAssertEqual(vm.todayData?.due_today.count, 2, "Both today tasks should remain")
    }

    func testGuardKeepsNoDueDateTaskInServerBucket() async {
        let noDueDateTask = TestFactories.makeSampleTask(id: 1, title: "No Due Date")

        stubTodayResponse(dueToday: [noDueDateTask])

        let vm = makeViewModel()
        await vm.loadToday()

        XCTAssertEqual(vm.todayData?.due_today.count, 1, "No-due-date task should stay in due_today")
    }
}
