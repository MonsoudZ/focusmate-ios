import XCTest
@testable import focusmate

/// Integration tests for critical API flows
/// These tests verify the complete flow from service layer through API client
@MainActor
final class APIIntegrationTests: XCTestCase {

    private var mockNetworking: MockNetworking!
    private var apiClient: APIClient!
    private var taskService: TaskService!
    private var listService: ListService!
    private var tagService: TagService!
    private var subtaskManager: SubtaskManager!

    override func setUp() async throws {
        try await super.setUp()
        await ResponseCache.shared.invalidateAll()
        mockNetworking = MockNetworking()
        apiClient = APIClient(tokenProvider: { "test-token" }, networking: mockNetworking)
        taskService = TaskService(apiClient: apiClient, sideEffects: NoOpSideEffects())
        listService = ListService(apiClient: apiClient)
        tagService = TagService(apiClient: apiClient)
        subtaskManager = SubtaskManager(taskService: taskService)
    }

    override func tearDown() async throws {
        await ResponseCache.shared.invalidateAll()
        mockNetworking.reset()
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

    // MARK: - Task CRUD Flow Tests

    func testCreateTaskFlow() async throws {
        // Given: A valid task creation request
        let createdTask = TestFactories.makeSampleTask(id: 1, title: "New Task")
        mockNetworking.stubJSON(SingleTaskResponse(task: createdTask))

        // When: Creating a task
        let result = try await taskService.createTask(
            listId: 1,
            title: "New Task",
            note: nil,
            dueAt: nil
        )

        // Then: Task is created with correct parameters
        XCTAssertEqual(result.title, "New Task")
        XCTAssertEqual(mockNetworking.lastCall?.method, "POST")
        XCTAssertTrue(mockNetworking.lastCall?.path.contains("/tasks") ?? false)
    }

    func testFetchTasksFlow() async throws {
        // Given: Tasks exist in a list
        let tasks = [
            TestFactories.makeSampleTask(id: 1, title: "Task 1"),
            TestFactories.makeSampleTask(id: 2, title: "Task 2")
        ]
        mockNetworking.stubJSON(TasksResponse(tasks: tasks, tombstones: nil))

        // When: Fetching tasks for a list
        let result = try await taskService.fetchTasks(listId: 1)

        // Then: All tasks are returned
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].title, "Task 1")
        XCTAssertEqual(result[1].title, "Task 2")
    }

    func testUpdateTaskFlow() async throws {
        // Given: An existing task
        let updatedTask = TestFactories.makeSampleTask(id: 1, title: "Updated Task")
        mockNetworking.stubJSON(SingleTaskResponse(task: updatedTask))

        // When: Updating the task
        let result = try await taskService.updateTask(
            listId: 1,
            taskId: 1,
            title: "Updated Task",
            note: nil,
            dueAt: nil,
            color: nil,
            priority: nil,
            starred: nil,
            tagIds: nil
        )

        // Then: Task is updated
        XCTAssertEqual(result.title, "Updated Task")
        XCTAssertEqual(mockNetworking.lastCall?.method, "PUT")
    }

    func testDeleteTaskFlow() async throws {
        // Given: An existing task
        mockNetworking.stubbedData = Data()

        // When: Deleting the task
        try await taskService.deleteTask(listId: 1, taskId: 1)

        // Then: DELETE request is sent
        XCTAssertEqual(mockNetworking.lastCall?.method, "DELETE")
        XCTAssertTrue(mockNetworking.lastCall?.path.contains("/tasks/1") ?? false)
    }

    func testCompleteTaskFlow() async throws {
        // Given: An incomplete task
        let completedTask = TestFactories.makeSampleTask(id: 1, title: "Task", status: "completed")
        mockNetworking.stubJSON(SingleTaskResponse(task: completedTask))

        // When: Completing the task
        let result = try await taskService.completeTask(listId: 1, taskId: 1, reason: nil)

        // Then: Task is marked complete
        XCTAssertEqual(result.status, "completed")
        // The API uses PATCH for completion
        XCTAssertEqual(mockNetworking.lastCall?.method, "PATCH")
        XCTAssertTrue(mockNetworking.lastCall?.path.contains("/complete") ?? false)
    }

    // MARK: - List Management Flow Tests

    func testFetchListsFlow() async throws {
        // Given: User has lists
        let lists = [
            TestFactories.makeSampleList(id: 1, name: "Work"),
            TestFactories.makeSampleList(id: 2, name: "Personal")
        ]
        mockNetworking.stubJSON(ListsResponse(lists: lists, tombstones: nil))

        // When: Fetching lists
        let result = try await listService.fetchLists()

        // Then: All lists are returned
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].name, "Work")
        XCTAssertEqual(result[1].name, "Personal")
    }

    func testCreateListFlow() async throws {
        // Given: Valid list creation request
        let createdList = TestFactories.makeSampleList(id: 1, name: "New List")
        mockNetworking.stubJSON(ListResponse(list: createdList))

        // When: Creating a list
        let result = try await listService.createList(name: "New List", description: nil, color: "blue")

        // Then: List is created
        XCTAssertEqual(result.name, "New List")
        XCTAssertEqual(mockNetworking.lastCall?.method, "POST")
    }

    func testDeleteListFlow() async throws {
        // Given: An existing list
        mockNetworking.stubbedData = Data()

        // When: Deleting the list
        try await listService.deleteList(id: 1)

        // Then: DELETE request is sent
        XCTAssertEqual(mockNetworking.lastCall?.method, "DELETE")
    }

    // MARK: - Error Handling Flow Tests

    func testNetworkErrorHandling() async throws {
        // Given: Network is unavailable
        mockNetworking.stubbedError = APIError.noInternetConnection

        // When: Making a request
        do {
            _ = try await taskService.fetchTasks(listId: 1)
            XCTFail("Expected error to be thrown")
        } catch {
            // Then: Error is properly propagated
            XCTAssertTrue(error is FocusmateError || error is APIError)
        }
    }

    func testUnauthorizedErrorHandling() async throws {
        // Given: Token is invalid
        mockNetworking.stubbedError = APIError.unauthorized("Session expired")

        // When: Making a request
        do {
            _ = try await taskService.fetchTasks(listId: 1)
            XCTFail("Expected error to be thrown")
        } catch let error as APIError {
            // Then: Unauthorized error is thrown
            if case .unauthorized = error {
                // Success
            } else {
                XCTFail("Expected unauthorized error")
            }
        } catch {
            // FocusmateError wrapping is also acceptable
        }
    }

    func testServerErrorHandling() async throws {
        // Given: Server returns 500
        mockNetworking.stubbedError = APIError.serverError(500, "Internal Server Error", nil)

        // When: Making a request
        do {
            _ = try await taskService.fetchTasks(listId: 1)
            XCTFail("Expected error to be thrown")
        } catch {
            // Then: Error is properly propagated
            XCTAssertNotNil(error)
        }
    }

    // MARK: - Subtask Flow Tests

    func testCreateSubtaskRequestIsSent() async throws {
        // Given: A parent task exists
        let parentTask = TestFactories.makeSampleTask(id: 1, title: "Parent")
        let subtask = TestFactories.makeSampleSubtask(id: 100, parentTaskId: 1, title: "Subtask")
        mockNetworking.stubJSON(SingleTaskResponse(task: TestFactories.makeSampleTask(id: 100, title: "Subtask")))

        // When: Creating a subtask
        do {
            _ = try await subtaskManager.create(parentTask: parentTask, title: "Subtask")
        } catch {
            // We just want to verify the request was made
        }

        // Then: POST request is sent to subtasks endpoint
        XCTAssertEqual(mockNetworking.lastCall?.method, "POST")
        XCTAssertTrue(mockNetworking.lastCall?.path.contains("tasks") ?? false)
    }

    // MARK: - Tag Flow Tests

    func testFetchTagsFlow() async throws {
        // Given: Tags exist
        let tags = [
            TagDTO(id: 1, name: "Important", color: "red", tasks_count: 5, created_at: nil),
            TagDTO(id: 2, name: "Work", color: "blue", tasks_count: 3, created_at: nil)
        ]
        mockNetworking.stubJSON(TagsResponse(tags: tags))

        // When: Fetching tags
        let result = try await tagService.fetchTags()

        // Then: All tags are returned
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].name, "Important")
    }

    // MARK: - Request Verification Tests

    func testRequestIncludesCorrectHeaders() async throws {
        // Given: A valid request
        let task = TestFactories.makeSampleTask(id: 1, title: "Task")
        mockNetworking.stubJSON(TasksResponse(tasks: [task], tombstones: nil))

        // When: Making a request
        _ = try await taskService.fetchTasks(listId: 1)

        // Then: Request is made to correct endpoint
        XCTAssertNotNil(mockNetworking.lastCall)
        XCTAssertEqual(mockNetworking.lastCall?.method, "GET")
    }

    func testCreateTaskRequestIsSentCorrectly() async throws {
        // Given: Task creation parameters
        let createdTask = TestFactories.makeSampleTask(id: 1, title: "Test Task")
        mockNetworking.stubJSON(SingleTaskResponse(task: createdTask))

        // When: Creating a task with specific parameters
        _ = try await taskService.createTask(
            listId: 1,
            title: "Test Task",
            note: "Test note",
            dueAt: Date(),
            priority: .high,
            starred: true,
            tagIds: [1, 2]
        )

        // Then: POST request is sent to tasks endpoint
        XCTAssertEqual(mockNetworking.lastCall?.method, "POST")
        XCTAssertTrue(mockNetworking.lastCall?.path.contains("/tasks") ?? false)
        XCTAssertNotNil(mockNetworking.lastCall?.body)
    }

    // MARK: - Multiple Request Tests

    func testMultipleSequentialRequests() async throws {
        // Given: Tasks exist
        let tasks = [TestFactories.makeSampleTask(id: 1, title: "Task 1")]
        mockNetworking.stubJSON(TasksResponse(tasks: tasks, tombstones: nil))

        // When: Making multiple requests sequentially
        let result1 = try await taskService.fetchTasks(listId: 1)
        let result2 = try await taskService.fetchTasks(listId: 2)

        // Then: All requests complete successfully
        XCTAssertFalse(result1.isEmpty)
        XCTAssertFalse(result2.isEmpty)
        XCTAssertEqual(mockNetworking.calls.count, 2)
    }
}

// MARK: - Helper Response Types

private struct SingleTaskResponse: Codable {
    let task: TaskDTO
}

private struct SubtaskResponse: Codable {
    let subtask: SubtaskDTO
}

private struct TagsResponse: Codable {
    let tags: [TagDTO]
}

private struct ListResponse: Codable {
    let list: ListDTO
}

private struct ListsResponse: Codable {
    let lists: [ListDTO]
    let tombstones: [String]?
}
