import XCTest
@testable import focusmate

@MainActor
final class TaskFormViewModelTests: XCTestCase {

    private var mockNetworking: MockNetworking!
    private var apiClient: APIClient!
    private var taskService: TaskService!
    private var tagService: TagService!

    override func setUp() async throws {
        try await super.setUp()
        // Clear any cached responses from previous tests
        await ResponseCache.shared.invalidateAll()
        mockNetworking = MockNetworking()
        apiClient = APIClient(tokenProvider: { nil }, networking: mockNetworking)
        taskService = TaskService(apiClient: apiClient, sideEffects: NoOpSideEffects())
        tagService = TagService(apiClient: apiClient)
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

    // MARK: - Init Tests

    func testInitWithExistingTaskPopulatesFields() async {
        await ResponseCache.shared.invalidateAll()

        let existingTask = TestFactories.makeSampleTask(
            id: 42,
            listId: 10,
            color: "green",
            title: "Existing Task",
            note: "Some notes here",
            dueAt: TestFactories.isoString(daysFromNow: 1, hour: 14, minute: 30),
            priority: TaskPriority.high.rawValue,
            starred: true,
            tags: [
                TagDTO(id: 1, name: "Work", color: "blue", tasks_count: nil, created_at: nil),
                TagDTO(id: 2, name: "Urgent", color: "red", tasks_count: nil, created_at: nil)
            ]
        )

        let vm = TaskFormViewModel(
            mode: .edit(listId: 10, task: existingTask),
            taskService: taskService,
            tagService: tagService
        )

        XCTAssertEqual(vm.title, "Existing Task")
        XCTAssertEqual(vm.note, "Some notes here")
        XCTAssertEqual(vm.selectedColor, "green")
        XCTAssertEqual(vm.selectedPriority, .high)
        XCTAssertTrue(vm.isStarred)
        XCTAssertEqual(vm.selectedTagIds, Set([1, 2]))
        XCTAssertTrue(vm.hasSpecificTime) // 14:30 is not midnight
        XCTAssertTrue(vm.hasDueDate)
    }

    func testInitWithoutTaskHasEmptyFields() async {
        await ResponseCache.shared.invalidateAll()

        let vm = TaskFormViewModel(
            mode: .create(listId: 5),
            taskService: taskService,
            tagService: tagService
        )

        XCTAssertEqual(vm.title, "")
        XCTAssertEqual(vm.note, "")
        XCTAssertNil(vm.selectedColor)
        XCTAssertEqual(vm.selectedPriority, .none)
        XCTAssertFalse(vm.isStarred)
        XCTAssertTrue(vm.selectedTagIds.isEmpty)
        XCTAssertFalse(vm.hasSpecificTime)
        XCTAssertEqual(vm.recurrencePattern, .none)
    }

    func testInitWithTaskTimeSettings() async {
        await ResponseCache.shared.invalidateAll()

        // Task at midnight (no specific time)
        let taskAtMidnight = TestFactories.makeSampleTask(
            id: 1,
            listId: 10,
            title: "Midnight Task",
            dueAt: TestFactories.midnightISOString(daysFromNow: 0)
        )
        let vmMidnight = TaskFormViewModel(
            mode: .edit(listId: 10, task: taskAtMidnight),
            taskService: taskService,
            tagService: tagService
        )
        XCTAssertFalse(vmMidnight.hasSpecificTime)

        // Task without due date
        let taskNoDue = TestFactories.makeSampleTask(
            id: 2,
            listId: 10,
            title: "No Due Task",
            dueAt: nil
        )
        let vmNoDue = TaskFormViewModel(
            mode: .edit(listId: 10, task: taskNoDue),
            taskService: taskService,
            tagService: tagService
        )
        XCTAssertFalse(vmNoDue.hasDueDate)
    }

    // MARK: - Save Tests

    func testSaveCreatesNewTaskWhenNoExisting() async {
        mockNetworking.stubJSON(TestFactories.makeSampleTask(id: 100, listId: 5, title: "New Task"))

        var dismissCalled = false
        let vm = TaskFormViewModel(
            mode: .create(listId: 5),
            taskService: taskService,
            tagService: tagService
        )
        vm.onDismiss = { dismissCalled = true }
        vm.title = "New Task"

        await vm.submit()

        let createCall = mockNetworking.calls.first { $0.method == "POST" }
        XCTAssertNotNil(createCall)
        XCTAssertTrue(createCall?.path.contains("lists/5/tasks") ?? false)

        let body = mockNetworking.lastBodyJSON
        let taskBody = body?["task"] as? [String: Any]
        XCTAssertEqual(taskBody?["title"] as? String, "New Task")

        XCTAssertTrue(dismissCalled)
    }

    func testSaveUpdatesExistingTask() async {
        let existingTask = TestFactories.makeSampleTask(id: 42, listId: 10, title: "Old Title")
        mockNetworking.stubJSON(TestFactories.makeSampleTask(id: 42, listId: 10, title: "Updated Title"))

        var saveCalled = false
        var dismissCalled = false
        let vm = TaskFormViewModel(
            mode: .edit(listId: 10, task: existingTask),
            taskService: taskService,
            tagService: tagService
        )
        vm.onSave = { saveCalled = true }
        vm.onDismiss = { dismissCalled = true }
        vm.title = "Updated Title"

        await vm.submit()

        let updateCall = mockNetworking.calls.first { $0.method == "PUT" }
        XCTAssertNotNil(updateCall)
        XCTAssertTrue(updateCall?.path.contains("42") ?? false)

        let body = mockNetworking.lastBodyJSON
        let taskBody = body?["task"] as? [String: Any]
        XCTAssertEqual(taskBody?["title"] as? String, "Updated Title")

        XCTAssertTrue(saveCalled)
        XCTAssertTrue(dismissCalled)
    }

    // MARK: - Validation Tests

    func testValidationRequiresTitleAndCannotSubmitWhileLoading() async {
        await ResponseCache.shared.invalidateAll()

        let vm = TaskFormViewModel(
            mode: .create(listId: 5),
            taskService: taskService,
            tagService: tagService
        )

        // Empty title
        vm.title = ""
        XCTAssertFalse(vm.canSubmit)

        // Whitespace only
        vm.title = "   "
        XCTAssertFalse(vm.canSubmit)

        // Valid title
        vm.title = "Valid Title"
        XCTAssertTrue(vm.canSubmit)

        // Loading state
        vm.isLoading = true
        XCTAssertFalse(vm.canSubmit)
    }

    func testEmptyTitleDoesNotSubmit() async {
        let vm = TaskFormViewModel(
            mode: .create(listId: 5),
            taskService: taskService,
            tagService: tagService
        )
        vm.title = ""

        await vm.submit()

        // No API calls should be made
        XCTAssertTrue(mockNetworking.calls.isEmpty)
    }

    // MARK: - Computed Properties Tests

    func testModeAndListId() async {
        // Ensure cache is clear
        await ResponseCache.shared.invalidateAll()

        // Test create mode
        let createVM = TaskFormViewModel(
            mode: .create(listId: 42),
            taskService: taskService,
            tagService: tagService
        )
        XCTAssertTrue(createVM.isCreateMode)
        XCTAssertEqual(createVM.listId, 42)

        // Test edit mode
        let editVM = TaskFormViewModel(
            mode: .edit(listId: 99, task: TestFactories.makeSampleTask(listId: 99)),
            taskService: taskService,
            tagService: tagService
        )
        XCTAssertFalse(editVM.isCreateMode)
        XCTAssertEqual(editVM.listId, 99)
    }

    func testFinalDueDateComputation() async {
        // Ensure cache is clear
        await ResponseCache.shared.invalidateAll()

        let vm = TaskFormViewModel(
            mode: .create(listId: 5),
            taskService: taskService,
            tagService: tagService
        )
        let calendar = Calendar.current

        // Without specific time, should be start of day
        vm.hasSpecificTime = false
        let startOfDay = calendar.startOfDay(for: vm.dueDate)
        XCTAssertEqual(vm.finalDueDate, startOfDay)

        // With specific time
        vm.hasSpecificTime = true
        let timeComponents = calendar.dateComponents([.hour, .minute], from: vm.dueTime)
        let expectedDate = calendar.date(
            bySettingHour: timeComponents.hour ?? 17,
            minute: timeComponents.minute ?? 0,
            second: 0,
            of: vm.dueDate
        )
        XCTAssertEqual(vm.finalDueDate, expectedDate)

        // Test no due date scenario
        let taskNoDue = TestFactories.makeSampleTask(id: 1, listId: 10, dueAt: nil)
        let editVM = TaskFormViewModel(
            mode: .edit(listId: 10, task: taskNoDue),
            taskService: taskService,
            tagService: tagService
        )
        editVM.hasDueDate = false
        XCTAssertNil(editVM.finalDueDate)
    }

    // MARK: - Recurrence Tests

    func testRecurrencePatternAndInterval() async {
        // Ensure cache is clear
        await ResponseCache.shared.invalidateAll()
        let vm = TaskFormViewModel(
            mode: .create(listId: 5),
            taskService: taskService,
            tagService: tagService
        )

        // Test isRecurring
        XCTAssertFalse(vm.isRecurring)
        vm.recurrencePattern = .daily
        XCTAssertTrue(vm.isRecurring)
        vm.recurrencePattern = .none
        XCTAssertFalse(vm.isRecurring)

        // Test recurrence interval unit
        vm.recurrencePattern = .daily
        vm.recurrenceInterval = 1
        XCTAssertEqual(vm.recurrenceIntervalUnit, "day")

        vm.recurrenceInterval = 2
        XCTAssertEqual(vm.recurrenceIntervalUnit, "days")

        vm.recurrencePattern = .weekly
        vm.recurrenceInterval = 1
        XCTAssertEqual(vm.recurrenceIntervalUnit, "week")
    }

    // MARK: - Quick Date Setters

    func testSetDueDateDaysFromNow() async {
        // Ensure cache is clear
        await ResponseCache.shared.invalidateAll()
        let vm = TaskFormViewModel(
            mode: .create(listId: 5),
            taskService: taskService,
            tagService: tagService
        )

        // Test setting due date to today
        vm.setDueDate(daysFromNow: 0)
        XCTAssertTrue(Calendar.current.isDateInToday(vm.dueDate))

        // Test setting due date to tomorrow
        vm.setDueDate(daysFromNow: 1)
        XCTAssertTrue(Calendar.current.isDateInTomorrow(vm.dueDate))

        // Test setting due date to next week
        vm.setDueDate(daysFromNow: 7)
        let today = Calendar.current.startOfDay(for: Date())
        guard let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: today) else {
            XCTFail("Failed to create next week date")
            return
        }
        XCTAssertTrue(Calendar.current.isDate(vm.dueDate, inSameDayAs: nextWeek))
    }

    // MARK: - Load Tags Test

    func testLoadTags() async {
        let tags = [
            TagDTO(id: 1, name: "Work", color: "blue", tasks_count: 5, created_at: nil),
            TagDTO(id: 2, name: "Personal", color: "green", tasks_count: 3, created_at: nil)
        ]
        mockNetworking.stubJSON(TagsResponse(tags: tags))

        let vm = TaskFormViewModel(
            mode: .create(listId: 5),
            taskService: taskService,
            tagService: tagService
        )

        await vm.loadTags()

        XCTAssertEqual(vm.availableTags.count, 2)
        XCTAssertEqual(vm.availableTags[0].name, "Work")
        XCTAssertEqual(vm.availableTags[1].name, "Personal")
    }

    // MARK: - Error Handling Tests

    func testSaveHandlesError() async {
        mockNetworking.stubbedError = APIError.serverError(500, "Failed to create", nil)

        let vm = TaskFormViewModel(
            mode: .create(listId: 5),
            taskService: taskService,
            tagService: tagService
        )
        vm.title = "Will Fail"

        await vm.submit()

        XCTAssertNotNil(vm.error)
        XCTAssertFalse(vm.isLoading)
    }
}
