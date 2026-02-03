import XCTest
@testable import focusmate

final class TaskServiceTests: XCTestCase {

    private var mock: MockNetworking!
    private var service: TaskService!

    override func setUp() {
        super.setUp()
        mock = MockNetworking()
        let apiClient = APIClient(tokenProvider: { nil }, networking: mock)
        service = TaskService(apiClient: apiClient, sideEffects: NoOpSideEffects())
    }

    private struct NoOpSideEffects: TaskSideEffectHandling {
        nonisolated init() {}
        func taskCreated(_ task: TaskDTO, isSubtask: Bool) {}
        func taskUpdated(_ task: TaskDTO) {}
        func taskDeleted(taskId: Int) {}
        func taskCompleted(taskId: Int) {}
        func taskReopened(_ task: TaskDTO) {}
    }

    // MARK: - Helpers

    private func stubTasksResponse(_ tasks: [TaskDTO] = []) {
        let response = TasksResponse(tasks: tasks, tombstones: nil)
        mock.stubJSON(response)
    }

    private func stubSingleTask(_ task: TaskDTO? = nil) {
        mock.stubJSON(task ?? TestFactories.makeSampleTask())
    }

    // MARK: - fetchTasks

    func testFetchTasksDecodesResponse() async throws {
        let task = TestFactories.makeSampleTask(id: 7, title: "Buy milk")
        stubTasksResponse([task])

        let result = try await service.fetchTasks(listId: 1)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, 7)
        XCTAssertEqual(result.first?.title, "Buy milk")
    }

    func testFetchTasksCallsCorrectEndpoint() async throws {
        stubTasksResponse()
        _ = try await service.fetchTasks(listId: 42)

        XCTAssertEqual(mock.lastCall?.method, "GET")
        XCTAssertEqual(mock.lastCall?.path, API.Lists.tasks("42"))
    }

    func testFetchTasksPropagatesError() async {
        mock.stubbedError = APIError.unauthorized(nil)

        do {
            _ = try await service.fetchTasks(listId: 1)
            XCTFail("Expected error to be thrown")
        } catch {
            // Error propagated (wrapped by ErrorHandler)
        }
    }

    // MARK: - fetchTask

    func testFetchSingleTask() async throws {
        let task = TestFactories.makeSampleTask(id: 5)
        stubSingleTask(task)

        let result = try await service.fetchTask(listId: 1, taskId: 5)
        XCTAssertEqual(result.id, 5)
        XCTAssertEqual(mock.lastCall?.method, "GET")
        XCTAssertEqual(mock.lastCall?.path, API.Lists.task("1", "5"))
    }

    // MARK: - createTask

    func testCreateTaskSendsCorrectBodyAndMethod() async throws {
        stubSingleTask()

        _ = try await service.createTask(
            listId: 1,
            title: "New Task",
            note: "Some note",
            dueAt: nil,
            priority: .high,
            starred: true
        )

        XCTAssertEqual(mock.lastCall?.method, "POST")
        XCTAssertEqual(mock.lastCall?.path, API.Lists.tasks("1"))

        let body = mock.lastBodyJSON
        let taskBody = body?["task"] as? [String: Any]
        XCTAssertEqual(taskBody?["title"] as? String, "New Task")
        XCTAssertEqual(taskBody?["note"] as? String, "Some note")
        XCTAssertEqual(taskBody?["priority"] as? Int, TaskPriority.high.rawValue)
        XCTAssertEqual(taskBody?["starred"] as? Bool, true)
    }

    func testCreateTaskReturnsCreatedTask() async throws {
        let task = TestFactories.makeSampleTask(id: 99, title: "Created")
        stubSingleTask(task)

        let result = try await service.createTask(
            listId: 1,
            title: "Created",
            note: nil,
            dueAt: nil
        )
        XCTAssertEqual(result.id, 99)
        XCTAssertEqual(result.title, "Created")
    }

    // MARK: - updateTask

    func testUpdateTaskSendsCorrectBodyAndMethod() async throws {
        stubSingleTask()

        _ = try await service.updateTask(
            listId: 1,
            taskId: 10,
            title: "Updated Title",
            note: "Updated note",
            dueAt: nil,
            priority: .medium
        )

        XCTAssertEqual(mock.lastCall?.method, "PUT")
        XCTAssertEqual(mock.lastCall?.path, API.Lists.task("1", "10"))

        let body = mock.lastBodyJSON
        let taskBody = body?["task"] as? [String: Any]
        XCTAssertEqual(taskBody?["title"] as? String, "Updated Title")
        XCTAssertEqual(taskBody?["note"] as? String, "Updated note")
        XCTAssertEqual(taskBody?["priority"] as? Int, TaskPriority.medium.rawValue)
    }

    func testUpdateTaskReturnsUpdatedTask() async throws {
        let task = TestFactories.makeSampleTask(id: 10, title: "Updated")
        stubSingleTask(task)

        let result = try await service.updateTask(
            listId: 1,
            taskId: 10,
            title: "Updated",
            note: nil,
            dueAt: nil
        )
        XCTAssertEqual(result.id, 10)
        XCTAssertEqual(result.title, "Updated")
    }

    // MARK: - deleteTask

    func testDeleteTaskCallsCorrectEndpoint() async throws {
        // EmptyResponse handled by mock
        try await service.deleteTask(listId: 1, taskId: 5)

        XCTAssertEqual(mock.lastCall?.method, "DELETE")
        XCTAssertEqual(mock.lastCall?.path, API.Lists.task("1", "5"))
    }

    func testDeleteTaskPropagatesError() async {
        mock.stubbedError = APIError.unauthorized(nil)

        do {
            try await service.deleteTask(listId: 1, taskId: 5)
            XCTFail("Expected error to be thrown")
        } catch {
            // Error propagated
        }
    }

    // MARK: - completeTask

    func testCompleteTaskSendsCorrectRequest() async throws {
        stubSingleTask()

        _ = try await service.completeTask(listId: 1, taskId: 10)

        XCTAssertEqual(mock.lastCall?.method, "PATCH")
        XCTAssertEqual(mock.lastCall?.path, API.Lists.taskAction("1", "10", "complete"))
    }

    func testCompleteTaskWithReason() async throws {
        stubSingleTask()

        _ = try await service.completeTask(listId: 1, taskId: 10, reason: "Was sick")

        let body = mock.lastBodyJSON
        XCTAssertEqual(body?["missed_reason"] as? String, "Was sick")
    }

    // MARK: - reopenTask

    func testReopenTaskSendsCorrectRequest() async throws {
        stubSingleTask()

        _ = try await service.reopenTask(listId: 1, taskId: 10)

        XCTAssertEqual(mock.lastCall?.method, "PATCH")
        XCTAssertEqual(mock.lastCall?.path, API.Lists.taskAction("1", "10", "reopen"))
    }

    // MARK: - reorderTasks

    func testReorderTasksSendsCorrectPayload() async throws {
        _ = try await service.reorderTasks(listId: 1, tasks: [
            (id: 3, position: 0),
            (id: 7, position: 1),
            (id: 1, position: 2),
        ])

        XCTAssertEqual(mock.lastCall?.method, "POST")
        XCTAssertEqual(mock.lastCall?.path, API.Lists.tasksReorder("1"))

        let body = mock.lastBodyJSON
        let tasks = body?["tasks"] as? [[String: Any]]
        XCTAssertEqual(tasks?.count, 3)
        XCTAssertEqual(tasks?[0]["id"] as? Int, 3)
        XCTAssertEqual(tasks?[0]["position"] as? Int, 0)
        XCTAssertEqual(tasks?[1]["id"] as? Int, 7)
        XCTAssertEqual(tasks?[1]["position"] as? Int, 1)
    }

    // MARK: - searchTasks

    func testSearchTasksSendsQuery() async throws {
        stubTasksResponse([TestFactories.makeSampleTask(title: "Found")])

        let results = try await service.searchTasks(query: "buy")

        XCTAssertEqual(mock.lastCall?.method, "GET")
        XCTAssertEqual(mock.lastCall?.path, API.Tasks.search)
        XCTAssertEqual(mock.lastCall?.queryParameters["q"], "buy")
        XCTAssertEqual(results.count, 1)
    }

    // MARK: - Subtask Methods

    func testCreateSubtaskSendsCorrectBody() async throws {
        let subtask = TestFactories.makeSampleSubtask(id: 100, title: "Sub item")
        mock.stubJSON(subtask)

        _ = try await service.createSubtask(listId: 1, parentTaskId: 10, title: "Sub item")

        XCTAssertEqual(mock.lastCall?.method, "POST")
        XCTAssertEqual(mock.lastCall?.path, API.Lists.subtasks("1", "10"))

        let body = mock.lastBodyJSON
        let subtaskBody = body?["subtask"] as? [String: Any]
        XCTAssertEqual(subtaskBody?["title"] as? String, "Sub item")
    }

    func testCompleteSubtaskSendsCorrectRequest() async throws {
        stubSingleTask()

        _ = try await service.completeSubtask(listId: 1, parentTaskId: 10, subtaskId: 50)

        XCTAssertEqual(mock.lastCall?.method, "PATCH")
        XCTAssertEqual(mock.lastCall?.path, API.Lists.subtaskAction("1", "10", "50", "complete"))
    }

    func testReopenSubtaskSendsCorrectRequest() async throws {
        stubSingleTask()

        _ = try await service.reopenSubtask(listId: 1, parentTaskId: 10, subtaskId: 50)

        XCTAssertEqual(mock.lastCall?.method, "PATCH")
        XCTAssertEqual(mock.lastCall?.path, API.Lists.subtaskAction("1", "10", "50", "reopen"))
    }

    func testDeleteSubtaskCallsCorrectEndpoint() async throws {
        try await service.deleteSubtask(listId: 1, parentTaskId: 10, subtaskId: 50)

        XCTAssertEqual(mock.lastCall?.method, "DELETE")
        XCTAssertEqual(mock.lastCall?.path, API.Lists.subtask("1", "10", "50"))
    }
}
