import Combine
@testable import focusmate
import XCTest

@MainActor
final class SubtaskManagerTests: XCTestCase {
  private var mock: MockNetworking!
  private var taskService: TaskService!
  private var manager: SubtaskManager!
  private var cancellables: Set<AnyCancellable>!

  private struct NoOpSideEffects: TaskSideEffectHandling {
    nonisolated init() {}
    func taskCreated(_ task: TaskDTO, isSubtask: Bool) {}
    func taskUpdated(_ task: TaskDTO) {}
    func taskDeleted(taskId: Int) {}
    func taskCompleted(taskId: Int) {}
    func taskReopened(_ task: TaskDTO) {}
  }

  override func setUp() {
    super.setUp()
    self.mock = MockNetworking()
    let apiClient = APIClient(tokenProvider: { nil }, networking: mock)
    self.taskService = TaskService(apiClient: apiClient, sideEffects: NoOpSideEffects())
    self.manager = SubtaskManager(taskService: self.taskService)
    self.cancellables = []
  }

  override func tearDown() {
    self.cancellables = nil
    super.tearDown()
  }

  // MARK: - Helpers

  private func stubSubtask(_ subtask: SubtaskDTO? = nil) {
    let response = SubtaskResponse(subtask: subtask ?? TestFactories.makeSampleSubtask())
    self.mock.stubJSON(response)
  }

  private func makeParentTask(id: Int = 1, listId: Int = 1) -> TaskDTO {
    TestFactories.makeSampleTask(id: id, listId: listId)
  }

  // MARK: - toggleComplete (not completed → complete)

  func testToggleCompleteCallsCompleteSubtask() async throws {
    let subtask = TestFactories.makeSampleSubtask(id: 50, completedAt: nil)
    let completed = TestFactories.makeSampleSubtask(id: 50, completedAt: "2025-01-01T00:00:00Z")
    self.stubSubtask(completed)

    let result = try await manager.toggleComplete(subtask: subtask, parentTask: self.makeParentTask())

    XCTAssertEqual(self.mock.lastCall?.method, "PATCH")
    XCTAssertEqual(self.mock.lastCall?.path, API.Lists.subtaskAction("1", "1", "50", "complete"))
    XCTAssertEqual(result.id, 50)
  }

  func testToggleCompletePublishesCompletedEvent() async throws {
    let subtask = TestFactories.makeSampleSubtask(id: 50, completedAt: nil)
    self.stubSubtask(TestFactories.makeSampleSubtask(id: 50, completedAt: "2025-01-01T00:00:00Z"))

    let expectation = XCTestExpectation(description: "Publishes completed event")
    var receivedChange: SubtaskChange?

    self.manager.changePublisher
      .sink { change in
        receivedChange = change
        expectation.fulfill()
      }
      .store(in: &self.cancellables)

    _ = try await self.manager.toggleComplete(subtask: subtask, parentTask: self.makeParentTask(id: 10, listId: 3))

    await fulfillment(of: [expectation], timeout: 1)

    XCTAssertEqual(receivedChange?.parentTaskId, 10)
    XCTAssertEqual(receivedChange?.listId, 3)
    if case let .completed(dto) = receivedChange?.type {
      XCTAssertEqual(dto.id, 50)
    } else {
      XCTFail("Expected .completed change type")
    }
  }

  // MARK: - toggleComplete (completed → reopen)

  func testToggleCompleteCallsReopenSubtask() async throws {
    let subtask = TestFactories.makeSampleSubtask(id: 50, completedAt: "2025-01-01T00:00:00Z")
    let reopened = TestFactories.makeSampleSubtask(id: 50, completedAt: nil)
    self.stubSubtask(reopened)

    let result = try await manager.toggleComplete(subtask: subtask, parentTask: self.makeParentTask())

    XCTAssertEqual(self.mock.lastCall?.method, "PATCH")
    XCTAssertEqual(self.mock.lastCall?.path, API.Lists.subtaskAction("1", "1", "50", "reopen"))
    XCTAssertEqual(result.id, 50)
  }

  func testToggleCompletePublishesReopenedEvent() async throws {
    let subtask = TestFactories.makeSampleSubtask(id: 50, completedAt: "2025-01-01T00:00:00Z")
    self.stubSubtask(TestFactories.makeSampleSubtask(id: 50, completedAt: nil))

    let expectation = XCTestExpectation(description: "Publishes reopened event")
    var receivedChange: SubtaskChange?

    self.manager.changePublisher
      .sink { change in
        receivedChange = change
        expectation.fulfill()
      }
      .store(in: &self.cancellables)

    _ = try await self.manager.toggleComplete(subtask: subtask, parentTask: self.makeParentTask())

    await fulfillment(of: [expectation], timeout: 1)

    if case .reopened = receivedChange?.type {
      // Expected
    } else {
      XCTFail("Expected .reopened change type")
    }
  }

  // MARK: - delete

  func testDeleteCallsCorrectEndpoint() async throws {
    let subtask = TestFactories.makeSampleSubtask(id: 50)

    try await self.manager.delete(subtask: subtask, parentTask: self.makeParentTask(id: 10, listId: 3))

    XCTAssertEqual(self.mock.lastCall?.method, "DELETE")
    XCTAssertEqual(self.mock.lastCall?.path, API.Lists.subtask("3", "10", "50"))
  }

  func testDeletePublishesDeletedEvent() async throws {
    let subtask = TestFactories.makeSampleSubtask(id: 50)

    let expectation = XCTestExpectation(description: "Publishes deleted event")
    var receivedChange: SubtaskChange?

    self.manager.changePublisher
      .sink { change in
        receivedChange = change
        expectation.fulfill()
      }
      .store(in: &self.cancellables)

    try await self.manager.delete(subtask: subtask, parentTask: self.makeParentTask(id: 10, listId: 3))

    await fulfillment(of: [expectation], timeout: 1)

    XCTAssertEqual(receivedChange?.parentTaskId, 10)
    XCTAssertEqual(receivedChange?.listId, 3)
    if case let .deleted(subtaskId) = receivedChange?.type {
      XCTAssertEqual(subtaskId, 50)
    } else {
      XCTFail("Expected .deleted change type")
    }
  }

  // MARK: - create

  func testCreateCallsCorrectEndpoint() async throws {
    self.stubSubtask(TestFactories.makeSampleSubtask(id: 200, title: "New sub"))

    let result = try await manager.create(parentTask: self.makeParentTask(id: 10, listId: 3), title: "New sub")

    XCTAssertEqual(self.mock.lastCall?.method, "POST")
    XCTAssertEqual(self.mock.lastCall?.path, API.Lists.subtasks("3", "10"))
    XCTAssertEqual(result.id, 200)
    XCTAssertEqual(result.title, "New sub")
  }

  func testCreatePublishesCreatedEvent() async throws {
    self.stubSubtask(TestFactories.makeSampleSubtask(id: 200))

    let expectation = XCTestExpectation(description: "Publishes created event")
    var receivedChange: SubtaskChange?

    self.manager.changePublisher
      .sink { change in
        receivedChange = change
        expectation.fulfill()
      }
      .store(in: &self.cancellables)

    _ = try await self.manager.create(parentTask: self.makeParentTask(id: 10, listId: 3), title: "New")

    await fulfillment(of: [expectation], timeout: 1)

    if case let .created(dto) = receivedChange?.type {
      XCTAssertEqual(dto.id, 200)
    } else {
      XCTFail("Expected .created change type")
    }
  }

  // MARK: - update

  func testUpdateCallsCorrectEndpoint() async throws {
    let subtask = TestFactories.makeSampleSubtask(id: 50, title: "Old")
    self.stubSubtask(TestFactories.makeSampleSubtask(id: 50, title: "New title"))

    let result = try await manager.update(
      subtask: subtask,
      parentTask: self.makeParentTask(id: 10, listId: 3),
      title: "New title"
    )

    XCTAssertEqual(self.mock.lastCall?.method, "PUT")
    XCTAssertEqual(self.mock.lastCall?.path, API.Lists.subtask("3", "10", "50"))
    XCTAssertEqual(result.title, "New title")
  }

  func testUpdatePublishesUpdatedEvent() async throws {
    let subtask = TestFactories.makeSampleSubtask(id: 50)
    self.stubSubtask(TestFactories.makeSampleSubtask(id: 50, title: "Updated"))

    let expectation = XCTestExpectation(description: "Publishes updated event")
    var receivedChange: SubtaskChange?

    self.manager.changePublisher
      .sink { change in
        receivedChange = change
        expectation.fulfill()
      }
      .store(in: &self.cancellables)

    _ = try await self.manager.update(subtask: subtask, parentTask: self.makeParentTask(), title: "Updated")

    await fulfillment(of: [expectation], timeout: 1)

    if case let .updated(dto) = receivedChange?.type {
      XCTAssertEqual(dto.title, "Updated")
    } else {
      XCTFail("Expected .updated change type")
    }
  }

  // MARK: - Error propagation

  func testToggleCompletePropagatesError() async {
    self.mock.stubbedError = APIError.unauthorized(nil)
    let subtask = TestFactories.makeSampleSubtask()

    do {
      _ = try await self.manager.toggleComplete(subtask: subtask, parentTask: self.makeParentTask())
      XCTFail("Expected error to be thrown")
    } catch {
      // Error propagated
    }
  }

  func testDeletePropagatesError() async {
    self.mock.stubbedError = APIError.unauthorized(nil)
    let subtask = TestFactories.makeSampleSubtask()

    do {
      try await self.manager.delete(subtask: subtask, parentTask: self.makeParentTask())
      XCTFail("Expected error to be thrown")
    } catch {
      // Error propagated
    }
  }

  func testCreatePropagatesError() async {
    self.mock.stubbedError = APIError.unauthorized(nil)

    do {
      _ = try await self.manager.create(parentTask: self.makeParentTask(), title: "New")
      XCTFail("Expected error to be thrown")
    } catch {
      // Error propagated
    }
  }
}
