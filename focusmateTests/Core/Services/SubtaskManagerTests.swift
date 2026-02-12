import Combine
import XCTest
@testable import focusmate

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
        mock = MockNetworking()
        let apiClient = APIClient(tokenProvider: { nil }, networking: mock)
        taskService = TaskService(apiClient: apiClient, sideEffects: NoOpSideEffects())
        manager = SubtaskManager(taskService: taskService)
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func stubSubtask(_ subtask: SubtaskDTO? = nil) {
        let response = SubtaskResponse(subtask: subtask ?? TestFactories.makeSampleSubtask())
        mock.stubJSON(response)
    }

    private func makeParentTask(id: Int = 1, listId: Int = 1) -> TaskDTO {
        TestFactories.makeSampleTask(id: id, listId: listId)
    }

    // MARK: - toggleComplete (not completed → complete)

    func testToggleCompleteCallsCompleteSubtask() async throws {
        let subtask = TestFactories.makeSampleSubtask(id: 50, completedAt: nil)
        let completed = TestFactories.makeSampleSubtask(id: 50, completedAt: "2025-01-01T00:00:00Z")
        stubSubtask(completed)

        let result = try await manager.toggleComplete(subtask: subtask, parentTask: makeParentTask())

        XCTAssertEqual(mock.lastCall?.method, "PATCH")
        XCTAssertEqual(mock.lastCall?.path, API.Lists.subtaskAction("1", "1", "50", "complete"))
        XCTAssertEqual(result.id, 50)
    }

    func testToggleCompletePublishesCompletedEvent() async throws {
        let subtask = TestFactories.makeSampleSubtask(id: 50, completedAt: nil)
        stubSubtask(TestFactories.makeSampleSubtask(id: 50, completedAt: "2025-01-01T00:00:00Z"))

        let expectation = XCTestExpectation(description: "Publishes completed event")
        var receivedChange: SubtaskChange?

        manager.changePublisher
            .sink { change in
                receivedChange = change
                expectation.fulfill()
            }
            .store(in: &cancellables)

        _ = try await manager.toggleComplete(subtask: subtask, parentTask: makeParentTask(id: 10, listId: 3))

        await fulfillment(of: [expectation], timeout: 1)

        XCTAssertEqual(receivedChange?.parentTaskId, 10)
        XCTAssertEqual(receivedChange?.listId, 3)
        if case .completed(let dto) = receivedChange?.type {
            XCTAssertEqual(dto.id, 50)
        } else {
            XCTFail("Expected .completed change type")
        }
    }

    // MARK: - toggleComplete (completed → reopen)

    func testToggleCompleteCallsReopenSubtask() async throws {
        let subtask = TestFactories.makeSampleSubtask(id: 50, completedAt: "2025-01-01T00:00:00Z")
        let reopened = TestFactories.makeSampleSubtask(id: 50, completedAt: nil)
        stubSubtask(reopened)

        let result = try await manager.toggleComplete(subtask: subtask, parentTask: makeParentTask())

        XCTAssertEqual(mock.lastCall?.method, "PATCH")
        XCTAssertEqual(mock.lastCall?.path, API.Lists.subtaskAction("1", "1", "50", "reopen"))
        XCTAssertEqual(result.id, 50)
    }

    func testToggleCompletePublishesReopenedEvent() async throws {
        let subtask = TestFactories.makeSampleSubtask(id: 50, completedAt: "2025-01-01T00:00:00Z")
        stubSubtask(TestFactories.makeSampleSubtask(id: 50, completedAt: nil))

        let expectation = XCTestExpectation(description: "Publishes reopened event")
        var receivedChange: SubtaskChange?

        manager.changePublisher
            .sink { change in
                receivedChange = change
                expectation.fulfill()
            }
            .store(in: &cancellables)

        _ = try await manager.toggleComplete(subtask: subtask, parentTask: makeParentTask())

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

        try await manager.delete(subtask: subtask, parentTask: makeParentTask(id: 10, listId: 3))

        XCTAssertEqual(mock.lastCall?.method, "DELETE")
        XCTAssertEqual(mock.lastCall?.path, API.Lists.subtask("3", "10", "50"))
    }

    func testDeletePublishesDeletedEvent() async throws {
        let subtask = TestFactories.makeSampleSubtask(id: 50)

        let expectation = XCTestExpectation(description: "Publishes deleted event")
        var receivedChange: SubtaskChange?

        manager.changePublisher
            .sink { change in
                receivedChange = change
                expectation.fulfill()
            }
            .store(in: &cancellables)

        try await manager.delete(subtask: subtask, parentTask: makeParentTask(id: 10, listId: 3))

        await fulfillment(of: [expectation], timeout: 1)

        XCTAssertEqual(receivedChange?.parentTaskId, 10)
        XCTAssertEqual(receivedChange?.listId, 3)
        if case .deleted(let subtaskId) = receivedChange?.type {
            XCTAssertEqual(subtaskId, 50)
        } else {
            XCTFail("Expected .deleted change type")
        }
    }

    // MARK: - create

    func testCreateCallsCorrectEndpoint() async throws {
        stubSubtask(TestFactories.makeSampleSubtask(id: 200, title: "New sub"))

        let result = try await manager.create(parentTask: makeParentTask(id: 10, listId: 3), title: "New sub")

        XCTAssertEqual(mock.lastCall?.method, "POST")
        XCTAssertEqual(mock.lastCall?.path, API.Lists.subtasks("3", "10"))
        XCTAssertEqual(result.id, 200)
        XCTAssertEqual(result.title, "New sub")
    }

    func testCreatePublishesCreatedEvent() async throws {
        stubSubtask(TestFactories.makeSampleSubtask(id: 200))

        let expectation = XCTestExpectation(description: "Publishes created event")
        var receivedChange: SubtaskChange?

        manager.changePublisher
            .sink { change in
                receivedChange = change
                expectation.fulfill()
            }
            .store(in: &cancellables)

        _ = try await manager.create(parentTask: makeParentTask(id: 10, listId: 3), title: "New")

        await fulfillment(of: [expectation], timeout: 1)

        if case .created(let dto) = receivedChange?.type {
            XCTAssertEqual(dto.id, 200)
        } else {
            XCTFail("Expected .created change type")
        }
    }

    // MARK: - update

    func testUpdateCallsCorrectEndpoint() async throws {
        let subtask = TestFactories.makeSampleSubtask(id: 50, title: "Old")
        stubSubtask(TestFactories.makeSampleSubtask(id: 50, title: "New title"))

        let result = try await manager.update(
            subtask: subtask,
            parentTask: makeParentTask(id: 10, listId: 3),
            title: "New title"
        )

        XCTAssertEqual(mock.lastCall?.method, "PUT")
        XCTAssertEqual(mock.lastCall?.path, API.Lists.subtask("3", "10", "50"))
        XCTAssertEqual(result.title, "New title")
    }

    func testUpdatePublishesUpdatedEvent() async throws {
        let subtask = TestFactories.makeSampleSubtask(id: 50)
        stubSubtask(TestFactories.makeSampleSubtask(id: 50, title: "Updated"))

        let expectation = XCTestExpectation(description: "Publishes updated event")
        var receivedChange: SubtaskChange?

        manager.changePublisher
            .sink { change in
                receivedChange = change
                expectation.fulfill()
            }
            .store(in: &cancellables)

        _ = try await manager.update(subtask: subtask, parentTask: makeParentTask(), title: "Updated")

        await fulfillment(of: [expectation], timeout: 1)

        if case .updated(let dto) = receivedChange?.type {
            XCTAssertEqual(dto.title, "Updated")
        } else {
            XCTFail("Expected .updated change type")
        }
    }

    // MARK: - Error propagation

    func testToggleCompletePropagatesError() async {
        mock.stubbedError = APIError.unauthorized(nil)
        let subtask = TestFactories.makeSampleSubtask()

        do {
            _ = try await manager.toggleComplete(subtask: subtask, parentTask: makeParentTask())
            XCTFail("Expected error to be thrown")
        } catch {
            // Error propagated
        }
    }

    func testDeletePropagatesError() async {
        mock.stubbedError = APIError.unauthorized(nil)
        let subtask = TestFactories.makeSampleSubtask()

        do {
            try await manager.delete(subtask: subtask, parentTask: makeParentTask())
            XCTFail("Expected error to be thrown")
        } catch {
            // Error propagated
        }
    }

    func testCreatePropagatesError() async {
        mock.stubbedError = APIError.unauthorized(nil)

        do {
            _ = try await manager.create(parentTask: makeParentTask(), title: "New")
            XCTFail("Expected error to be thrown")
        } catch {
            // Error propagated
        }
    }
}
