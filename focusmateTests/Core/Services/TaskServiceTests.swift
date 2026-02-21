@testable import focusmate
import XCTest

@MainActor
final class TaskServiceTests: XCTestCase {
  private var mock: MockNetworking!
  private var service: TaskService!

  override func setUp() {
    super.setUp()
    self.mock = MockNetworking()
    let apiClient = APIClient(tokenProvider: { nil }, networking: mock)
    self.service = TaskService(apiClient: apiClient, sideEffects: NoOpSideEffects())
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
    self.mock.stubJSON(response)
  }

  private func stubSingleTask(_ task: TaskDTO? = nil) {
    let response = SingleTaskResponse(task: task ?? TestFactories.makeSampleTask())
    self.mock.stubJSON(response)
  }

  private func stubSubtask(_ subtask: SubtaskDTO? = nil) {
    let response = SubtaskResponse(subtask: subtask ?? TestFactories.makeSampleSubtask())
    self.mock.stubJSON(response)
  }

  // MARK: - fetchTasks

  func testFetchTasksDecodesResponse() async throws {
    let task = TestFactories.makeSampleTask(id: 7, title: "Buy milk")
    self.stubTasksResponse([task])

    let result = try await service.fetchTasks(listId: 1)

    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result.first?.id, 7)
    XCTAssertEqual(result.first?.title, "Buy milk")
  }

  func testFetchTasksCallsCorrectEndpoint() async throws {
    self.stubTasksResponse()
    _ = try await self.service.fetchTasks(listId: 42)

    XCTAssertEqual(self.mock.lastCall?.method, "GET")
    XCTAssertEqual(self.mock.lastCall?.path, API.Lists.tasks("42"))
  }

  func testFetchTasksPropagatesError() async {
    self.mock.stubbedError = APIError.unauthorized(nil)

    do {
      _ = try await self.service.fetchTasks(listId: 1)
      XCTFail("Expected error to be thrown")
    } catch {
      // Error propagated (wrapped by ErrorHandler)
    }
  }

  // MARK: - fetchTask

  func testFetchSingleTask() async throws {
    let task = TestFactories.makeSampleTask(id: 5)
    self.stubSingleTask(task)

    let result = try await service.fetchTask(listId: 1, taskId: 5)
    XCTAssertEqual(result.id, 5)
    XCTAssertEqual(self.mock.lastCall?.method, "GET")
    XCTAssertEqual(self.mock.lastCall?.path, API.Lists.task("1", "5"))
  }

  // MARK: - createTask

  func testCreateTaskSendsCorrectBodyAndMethod() async throws {
    self.stubSingleTask()

    _ = try await self.service.createTask(
      listId: 1,
      title: "New Task",
      note: "Some note",
      dueAt: nil,
      priority: .high,
      starred: true
    )

    XCTAssertEqual(self.mock.lastCall?.method, "POST")
    XCTAssertEqual(self.mock.lastCall?.path, API.Lists.tasks("1"))

    let body = self.mock.lastBodyJSON
    let taskBody = body?["task"] as? [String: Any]
    XCTAssertEqual(taskBody?["title"] as? String, "New Task")
    XCTAssertEqual(taskBody?["note"] as? String, "Some note")
    XCTAssertEqual(taskBody?["priority"] as? Int, TaskPriority.high.rawValue)
    XCTAssertEqual(taskBody?["starred"] as? Bool, true)
  }

  func testCreateTaskReturnsCreatedTask() async throws {
    let task = TestFactories.makeSampleTask(id: 99, title: "Created")
    self.stubSingleTask(task)

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
    self.stubSingleTask()

    _ = try await self.service.updateTask(
      listId: 1,
      taskId: 10,
      title: "Updated Title",
      note: "Updated note",
      dueAt: nil,
      priority: .medium
    )

    XCTAssertEqual(self.mock.lastCall?.method, "PUT")
    XCTAssertEqual(self.mock.lastCall?.path, API.Lists.task("1", "10"))

    let body = self.mock.lastBodyJSON
    let taskBody = body?["task"] as? [String: Any]
    XCTAssertEqual(taskBody?["title"] as? String, "Updated Title")
    XCTAssertEqual(taskBody?["note"] as? String, "Updated note")
    XCTAssertEqual(taskBody?["priority"] as? Int, TaskPriority.medium.rawValue)
  }

  func testUpdateTaskReturnsUpdatedTask() async throws {
    let task = TestFactories.makeSampleTask(id: 10, title: "Updated")
    self.stubSingleTask(task)

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
    try await self.service.deleteTask(listId: 1, taskId: 5)

    XCTAssertEqual(self.mock.lastCall?.method, "DELETE")
    XCTAssertEqual(self.mock.lastCall?.path, API.Lists.task("1", "5"))
  }

  func testDeleteTaskPropagatesError() async {
    self.mock.stubbedError = APIError.unauthorized(nil)

    do {
      try await self.service.deleteTask(listId: 1, taskId: 5)
      XCTFail("Expected error to be thrown")
    } catch {
      // Error propagated
    }
  }

  // MARK: - completeTask

  func testCompleteTaskSendsCorrectRequest() async throws {
    self.stubSingleTask()

    _ = try await self.service.completeTask(listId: 1, taskId: 10)

    XCTAssertEqual(self.mock.lastCall?.method, "PATCH")
    XCTAssertEqual(self.mock.lastCall?.path, API.Lists.taskAction("1", "10", "complete"))
  }

  func testCompleteTaskWithReason() async throws {
    self.stubSingleTask()

    _ = try await self.service.completeTask(listId: 1, taskId: 10, reason: "Was sick")

    let body = self.mock.lastBodyJSON
    XCTAssertEqual(body?["missed_reason"] as? String, "Was sick")
  }

  // MARK: - reopenTask

  func testReopenTaskSendsCorrectRequest() async throws {
    self.stubSingleTask()

    _ = try await self.service.reopenTask(listId: 1, taskId: 10)

    XCTAssertEqual(self.mock.lastCall?.method, "PATCH")
    XCTAssertEqual(self.mock.lastCall?.path, API.Lists.taskAction("1", "10", "reopen"))
  }

  // MARK: - reorderTasks

  func testReorderTasksSendsCorrectPayload() async throws {
    _ = try await self.service.reorderTasks(listId: 1, tasks: [
      (id: 3, position: 0),
      (id: 7, position: 1),
      (id: 1, position: 2),
    ])

    XCTAssertEqual(self.mock.lastCall?.method, "POST")
    XCTAssertEqual(self.mock.lastCall?.path, API.Lists.tasksReorder("1"))

    let body = self.mock.lastBodyJSON
    let tasks = body?["tasks"] as? [[String: Any]]
    XCTAssertEqual(tasks?.count, 3)
    XCTAssertEqual(tasks?[0]["id"] as? Int, 3)
    XCTAssertEqual(tasks?[0]["position"] as? Int, 0)
    XCTAssertEqual(tasks?[1]["id"] as? Int, 7)
    XCTAssertEqual(tasks?[1]["position"] as? Int, 1)
  }

  // MARK: - searchTasks

  func testSearchTasksSendsQuery() async throws {
    self.stubTasksResponse([TestFactories.makeSampleTask(title: "Found")])

    let results = try await service.searchTasks(query: "buy")

    XCTAssertEqual(self.mock.lastCall?.method, "GET")
    XCTAssertEqual(self.mock.lastCall?.path, API.Tasks.search)
    XCTAssertEqual(self.mock.lastCall?.queryParameters["q"], "buy")
    XCTAssertEqual(results.count, 1)
  }

  // MARK: - Subtask Methods

  func testCreateSubtaskSendsCorrectBody() async throws {
    let subtask = TestFactories.makeSampleSubtask(id: 100, title: "Sub item")
    self.stubSubtask(subtask)

    _ = try await self.service.createSubtask(listId: 1, parentTaskId: 10, title: "Sub item")

    XCTAssertEqual(self.mock.lastCall?.method, "POST")
    XCTAssertEqual(self.mock.lastCall?.path, API.Lists.subtasks("1", "10"))

    let body = self.mock.lastBodyJSON
    let subtaskBody = body?["subtask"] as? [String: Any]
    XCTAssertEqual(subtaskBody?["title"] as? String, "Sub item")
  }

  func testCompleteSubtaskSendsCorrectRequest() async throws {
    self.stubSubtask()

    _ = try await self.service.completeSubtask(listId: 1, parentTaskId: 10, subtaskId: 50)

    XCTAssertEqual(self.mock.lastCall?.method, "PATCH")
    XCTAssertEqual(self.mock.lastCall?.path, API.Lists.subtaskAction("1", "10", "50", "complete"))
  }

  func testReopenSubtaskSendsCorrectRequest() async throws {
    self.stubSubtask()

    _ = try await self.service.reopenSubtask(listId: 1, parentTaskId: 10, subtaskId: 50)

    XCTAssertEqual(self.mock.lastCall?.method, "PATCH")
    XCTAssertEqual(self.mock.lastCall?.path, API.Lists.subtaskAction("1", "10", "50", "reopen"))
  }

  func testDeleteSubtaskCallsCorrectEndpoint() async throws {
    try await self.service.deleteSubtask(listId: 1, parentTaskId: 10, subtaskId: 50)

    XCTAssertEqual(self.mock.lastCall?.method, "DELETE")
    XCTAssertEqual(self.mock.lastCall?.path, API.Lists.subtask("1", "10", "50"))
  }
}
