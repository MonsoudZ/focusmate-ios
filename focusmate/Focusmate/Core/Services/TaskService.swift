import Foundation

final class TaskService {
    let apiClient: APIClient
    private let sideEffects: TaskSideEffectHandling

    init(apiClient: APIClient, sideEffects: TaskSideEffectHandling) {
        self.apiClient = apiClient
        self.sideEffects = sideEffects
    }

    // MARK: - Input Validation

    private func validateListId(_ listId: Int) throws {
        guard listId > 0 else {
            throw FocusmateError.validation(["list_id": ["must be a positive number"]], nil)
        }
    }

    private func validateTaskId(_ taskId: Int) throws {
        guard taskId > 0 else {
            throw FocusmateError.validation(["task_id": ["must be a positive number"]], nil)
        }
    }

    private func validateTitle(_ title: String) throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FocusmateError.validation(["title": ["cannot be empty"]], nil)
        }
    }

    private func validateSubtaskId(_ subtaskId: Int) throws {
        guard subtaskId > 0 else {
            throw FocusmateError.validation(["subtask_id": ["must be a positive number"]], nil)
        }
    }

    // MARK: - Task Operations

    func fetchTasks(listId: Int) async throws -> [TaskDTO] {
        try validateListId(listId)
        do {
            let response: TasksResponse = try await apiClient.request(
                "GET",
                API.Lists.tasks(String(listId)),
                body: nil as String?
            )
            return response.tasks
        } catch {
            throw ErrorHandler.shared.handle(error, context: "Fetching tasks")
        }
    }

    func fetchTask(listId: Int, taskId: Int) async throws -> TaskDTO {
        try validateListId(listId)
        try validateTaskId(taskId)
        do {
            let response: SingleTaskResponse = try await apiClient.request(
                "GET",
                API.Lists.task(String(listId), String(taskId)),
                body: nil as String?
            )
            return response.task
        } catch {
            throw ErrorHandler.shared.handle(error, context: "Fetching task")
        }
    }

    /// Fetch a task by ID without knowing the list ID (for deep links)
    func fetchTaskById(_ taskId: Int) async throws -> TaskDTO {
        try validateTaskId(taskId)
        do {
            let response: SingleTaskResponse = try await apiClient.request(
                "GET",
                API.Tasks.id(String(taskId)),
                body: nil as String?
            )
            return response.task
        } catch {
            throw ErrorHandler.shared.handle(error, context: "Fetching task")
        }
    }

    func createTask(
        listId: Int,
        title: String,
        note: String?,
        dueAt: Date?,
        color: String? = nil,
        priority: TaskPriority = .none,
        starred: Bool = false,
        tagIds: [Int] = [],
        isRecurring: Bool = false,
        recurrencePattern: String? = nil,
        recurrenceInterval: Int? = nil,
        recurrenceDays: [Int]? = nil,
        recurrenceEndDate: Date? = nil,
        recurrenceCount: Int? = nil,
        parentTaskId: Int? = nil
    ) async throws -> TaskDTO {
        try validateListId(listId)
        try validateTitle(title)
        do {
            let request = CreateTaskRequest(task: .init(
                title: title,
                note: note,
                due_at: dueAt?.ISO8601Format(),
                color: color,
                priority: priority.rawValue,
                starred: starred,
                tag_ids: tagIds.isEmpty ? nil : tagIds,
                is_recurring: isRecurring ? true : nil,
                recurrence_pattern: recurrencePattern,
                recurrence_interval: recurrenceInterval,
                recurrence_days: recurrenceDays,
                recurrence_end_date: recurrenceEndDate?.ISO8601Format(),
                recurrence_count: recurrenceCount,
                parent_task_id: parentTaskId
            ))
            let response: SingleTaskResponse = try await apiClient.request(
                "POST",
                API.Lists.tasks(String(listId)),
                body: request
            )

            await MainActor.run { sideEffects.taskCreated(response.task, isSubtask: parentTaskId != nil) }

            return response.task
        } catch {
            throw ErrorHandler.shared.handle(error, context: "Creating task")
        }
    }

    func updateTask(listId: Int, taskId: Int, title: String?, note: String?, dueAt: String?, color: String? = nil, priority: TaskPriority? = nil, starred: Bool? = nil, hidden: Bool? = nil, tagIds: [Int]? = nil) async throws -> TaskDTO {
        try validateListId(listId)
        try validateTaskId(taskId)
        if let title, title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw FocusmateError.validation(["title": ["cannot be empty"]], nil)
        }
        do {
            let request = UpdateTaskRequest(task: .init(
                title: title,
                note: note,
                due_at: dueAt,
                color: color,
                priority: priority?.rawValue,
                starred: starred,
                hidden: hidden,
                tag_ids: tagIds
            ))
            let response: SingleTaskResponse = try await apiClient.request(
                "PUT",
                API.Lists.task(String(listId), String(taskId)),
                body: request
            )

            await MainActor.run { sideEffects.taskUpdated(response.task) }

            return response.task
        } catch {
            throw ErrorHandler.shared.handle(error, context: "Updating task")
        }
    }

    func deleteTask(listId: Int, taskId: Int) async throws {
        try validateListId(listId)
        try validateTaskId(taskId)
        do {
            await MainActor.run { sideEffects.taskDeleted(taskId: taskId) }

            _ = try await apiClient.request(
                "DELETE",
                API.Lists.task(String(listId), String(taskId)),
                body: nil as String?
            ) as EmptyResponse
        } catch {
            throw ErrorHandler.shared.handle(error, context: "Deleting task")
        }
    }

    func completeTask(listId: Int, taskId: Int, reason: String? = nil) async throws -> TaskDTO {
        try validateListId(listId)
        try validateTaskId(taskId)
        do {
            // Only include reason if it's non-empty after trimming
            let trimmedReason = reason?.trimmingCharacters(in: .whitespacesAndNewlines)
            let body: CompleteTaskRequest? = trimmedReason.flatMap { $0.isEmpty ? nil : CompleteTaskRequest(missed_reason: $0) }
            let response: SingleTaskResponse = try await apiClient.request(
                "PATCH",
                API.Lists.taskAction(String(listId), String(taskId), "complete"),
                body: body
            )

            await MainActor.run { sideEffects.taskCompleted(taskId: taskId) }

            return response.task
        } catch {
            throw ErrorHandler.shared.handle(error, context: "Completing task")
        }
    }

    func reopenTask(listId: Int, taskId: Int) async throws -> TaskDTO {
        try validateListId(listId)
        try validateTaskId(taskId)
        do {
            let response: SingleTaskResponse = try await apiClient.request(
                "PATCH",
                API.Lists.taskAction(String(listId), String(taskId), "reopen"),
                body: nil as String?
            )

            await MainActor.run { sideEffects.taskReopened(response.task) }

            return response.task
        } catch {
            throw ErrorHandler.shared.handle(error, context: "Reopening task")
        }
    }

    func reorderTasks(listId: Int, tasks: [(id: Int, position: Int)]) async throws {
        try validateListId(listId)
        do {
            let request = ReorderTasksRequest(tasks: tasks.map { ReorderTask(id: $0.id, position: $0.position) })
            _ = try await apiClient.request(
                "POST",
                API.Lists.tasksReorder(String(listId)),
                body: request
            ) as EmptyResponse
        } catch {
            throw ErrorHandler.shared.handle(error, context: "Reordering tasks")
        }
    }
    
    func searchTasks(query: String) async throws -> [TaskDTO] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return [] // Return empty results for empty query instead of making API call
        }
        do {
            let response: TasksResponse = try await apiClient.request(
                "GET",
                API.Tasks.search,
                body: nil as String?,
                queryParameters: ["q": trimmedQuery]
            )
            return response.tasks
        } catch {
            throw ErrorHandler.shared.handle(error, context: "Searching tasks")
        }
    }
    
    // MARK: - Subtask Methods

    /// Create a subtask under a parent task
    func createSubtask(listId: Int, parentTaskId: Int, title: String) async throws -> SubtaskDTO {
        try validateSubtaskContext(listId: listId, parentTaskId: parentTaskId)
        try validateTitle(title)
        do {
            let request = CreateSubtaskRequest(subtask: .init(title: title))
            let response: SubtaskResponse = try await apiClient.request(
                "POST",
                API.Lists.subtasks(String(listId), String(parentTaskId)),
                body: request
            )
            Logger.debug("TaskService: Created subtask '\(title)' under task \(parentTaskId)", category: .api)
            return response.subtask
        } catch {
            throw ErrorHandler.shared.handle(error, context: "Creating subtask")
        }
    }

    /// Complete a subtask
    func completeSubtask(listId: Int, parentTaskId: Int, subtaskId: Int) async throws -> SubtaskDTO {
        try await performSubtaskAction(listId: listId, parentTaskId: parentTaskId, subtaskId: subtaskId, action: "complete")
    }

    /// Reopen a subtask
    func reopenSubtask(listId: Int, parentTaskId: Int, subtaskId: Int) async throws -> SubtaskDTO {
        try await performSubtaskAction(listId: listId, parentTaskId: parentTaskId, subtaskId: subtaskId, action: "reopen")
    }

    /// Update a subtask
    func updateSubtask(listId: Int, parentTaskId: Int, subtaskId: Int, title: String) async throws -> SubtaskDTO {
        try validateSubtaskContext(listId: listId, parentTaskId: parentTaskId, subtaskId: subtaskId)
        try validateTitle(title)
        do {
            let request = UpdateSubtaskRequest(subtask: .init(title: title))
            let response: SubtaskResponse = try await apiClient.request(
                "PUT",
                API.Lists.subtask(String(listId), String(parentTaskId), String(subtaskId)),
                body: request
            )
            Logger.debug("TaskService: Updated subtask \(subtaskId)", category: .api)
            return response.subtask
        } catch {
            throw ErrorHandler.shared.handle(error, context: "Updating subtask")
        }
    }

    /// Delete a subtask
    func deleteSubtask(listId: Int, parentTaskId: Int, subtaskId: Int) async throws {
        try validateSubtaskContext(listId: listId, parentTaskId: parentTaskId, subtaskId: subtaskId)
        do {
            _ = try await apiClient.request(
                "DELETE",
                API.Lists.subtask(String(listId), String(parentTaskId), String(subtaskId)),
                body: nil as String?
            ) as EmptyResponse
            Logger.debug("TaskService: Deleted subtask \(subtaskId)", category: .api)
        } catch {
            throw ErrorHandler.shared.handle(error, context: "Deleting subtask")
        }
    }

    // MARK: - Subtask Helpers

    private func validateSubtaskContext(listId: Int, parentTaskId: Int, subtaskId: Int? = nil) throws {
        try validateListId(listId)
        try validateTaskId(parentTaskId)
        if let subtaskId {
            try validateSubtaskId(subtaskId)
        }
    }

    /// Performs a PATCH action (complete/reopen) on a subtask
    private func performSubtaskAction(
        listId: Int,
        parentTaskId: Int,
        subtaskId: Int,
        action: String
    ) async throws -> SubtaskDTO {
        try validateSubtaskContext(listId: listId, parentTaskId: parentTaskId, subtaskId: subtaskId)
        do {
            let response: SubtaskResponse = try await apiClient.request(
                "PATCH",
                API.Lists.subtaskAction(String(listId), String(parentTaskId), String(subtaskId), action),
                body: nil as String?
            )
            Logger.debug("TaskService: \(action.capitalized) subtask \(subtaskId)", category: .api)
            return response.subtask
        } catch {
            throw ErrorHandler.shared.handle(error, context: "\(action.capitalized) subtask")
        }
    }

    // MARK: - Nudge

    func nudgeTask(listId: Int, taskId: Int) async throws {
        try validateListId(listId)
        try validateTaskId(taskId)
        do {
            let endpoint = API.Lists.taskAction(String(listId), String(taskId), "nudge")
            let _: NudgeResponse = try await apiClient.request("POST", endpoint, body: nil as String?)
            Logger.debug("TaskService: Nudged task \(taskId)", category: .api)
        } catch {
            throw ErrorHandler.shared.handle(error, context: "Nudging task")
        }
    }
}

// MARK: - Response Models

struct NudgeResponse: Codable {
    let message: String
}

// MARK: - Request Models (local to TaskService)

private struct CreateTaskRequest: Encodable {
    let task: TaskData
    struct TaskData: Encodable {
        let title: String
        let note: String?
        let due_at: String?
        let color: String?
        let priority: Int
        let starred: Bool
        let tag_ids: [Int]?
        let is_recurring: Bool?
        let recurrence_pattern: String?
        let recurrence_interval: Int?
        let recurrence_days: [Int]?
        let recurrence_end_date: String?
        let recurrence_count: Int?
        let parent_task_id: Int?
    }
}

private struct CreateSubtaskRequest: Encodable {
    let subtask: SubtaskData
    struct SubtaskData: Encodable {
        let title: String
    }
}

private struct UpdateSubtaskRequest: Encodable {
    let subtask: SubtaskData
    struct SubtaskData: Encodable {
        let title: String
    }
}

private struct UpdateTaskRequest: Encodable {
    let task: TaskData
    struct TaskData: Encodable {
        let title: String?
        let note: String?
        let due_at: String?
        let color: String?
        let priority: Int?
        let starred: Bool?
        let hidden: Bool?
        let tag_ids: [Int]?
    }
}

private struct CompleteTaskRequest: Encodable {
    let missed_reason: String
}

private struct ReorderTasksRequest: Encodable {
    let tasks: [ReorderTask]
}

private struct ReorderTask: Encodable {
    let id: Int
    let position: Int
}
