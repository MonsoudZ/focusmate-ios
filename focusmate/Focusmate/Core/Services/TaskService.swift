import Foundation

final class TaskService {
    let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchTasks(listId: Int) async throws -> [TaskDTO] {
        do {
            let response: TasksResponse = try await apiClient.request(
                "GET",
                API.Lists.tasks(String(listId)),
                body: nil as String?
            )
            Logger.debug("TaskService: Fetched \(response.tasks.count) tasks", category: .api)
            return response.tasks
        } catch {
            throw ErrorHandler.shared.handle(error, context: "Fetching tasks")
        }
    }

    func fetchTask(listId: Int, taskId: Int) async throws -> TaskDTO {
        do {
            return try await apiClient.request(
                "GET",
                API.Lists.task(String(listId), String(taskId)),
                body: nil as String?
            )
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
            let task: TaskDTO = try await apiClient.request(
                "POST",
                API.Lists.tasks(String(listId)),
                body: request
            )
            
            // Only schedule notifications for parent tasks
            if parentTaskId == nil {
                NotificationService.shared.scheduleTaskNotifications(for: task)
                CalendarService.shared.addTaskToCalendar(task)
            }
            
            return task
        } catch {
            throw ErrorHandler.shared.handle(error, context: "Creating task")
        }
    }

    func updateTask(listId: Int, taskId: Int, title: String?, note: String?, dueAt: String?, color: String? = nil, priority: TaskPriority? = nil, starred: Bool? = nil, tagIds: [Int]? = nil) async throws -> TaskDTO {
        do {
            let request = UpdateTaskRequest(task: .init(
                title: title,
                note: note,
                due_at: dueAt,
                color: color,
                priority: priority?.rawValue,
                starred: starred,
                tag_ids: tagIds
            ))
            let task: TaskDTO = try await apiClient.request(
                "PUT",
                API.Lists.task(String(listId), String(taskId)),
                body: request
            )
            
            // Update notifications
            NotificationService.shared.scheduleTaskNotifications(for: task)
            
            // Update calendar
            CalendarService.shared.updateTaskInCalendar(task)
            
            return task
        } catch {
            throw ErrorHandler.shared.handle(error, context: "Updating task")
        }
    }

    func deleteTask(listId: Int, taskId: Int) async throws {
        do {
            // Cancel notifications before deleting
            NotificationService.shared.cancelTaskNotifications(for: taskId)
            CalendarService.shared.removeTaskFromCalendar(taskId: taskId)
            
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
        do {
            let body: CompleteTaskRequest? = reason.map { CompleteTaskRequest(missed_reason: $0) }
            let task: TaskDTO = try await apiClient.request(
                "PATCH",
                API.Lists.taskAction(String(listId), String(taskId), "complete"),
                body: body
            )
            
            // Cancel notifications for completed task
            NotificationService.shared.cancelTaskNotifications(for: taskId)
            CalendarService.shared.removeTaskFromCalendar(taskId: taskId)
            
            return task
        } catch {
            throw ErrorHandler.shared.handle(error, context: "Completing task")
        }
    }

    func reopenTask(listId: Int, taskId: Int) async throws -> TaskDTO {
        do {
            let task: TaskDTO = try await apiClient.request(
                "PATCH",
                API.Lists.taskAction(String(listId), String(taskId), "reopen"),
                body: nil as String?
            )
            
            // Re-add notifications
            NotificationService.shared.scheduleTaskNotifications(for: task)
            
            // Re-add to calendar
            CalendarService.shared.addTaskToCalendar(task)
            
            return task
        } catch {
            throw ErrorHandler.shared.handle(error, context: "Reopening task")
        }
    }

    func reorderTasks(listId: Int, tasks: [(id: Int, position: Int)]) async throws {
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
        do {
            let response: TasksResponse = try await apiClient.request(
                "GET",
                API.Tasks.search,
                body: nil as String?,
                queryParameters: ["q": query]
            )
            return response.tasks
        } catch {
            throw ErrorHandler.shared.handle(error, context: "Searching tasks")
        }
    }
    
    // MARK: - Subtask Methods
    
    /// Create a subtask under a parent task
    func createSubtask(listId: Int, parentTaskId: Int, title: String) async throws -> TaskDTO {
        do {
            let request = CreateSubtaskRequest(task: .init(
                title: title,
                parent_task_id: parentTaskId
            ))
            
            let subtask: TaskDTO = try await apiClient.request(
                "POST",
                API.Lists.tasks(String(listId)),
                body: request
            )
            Logger.debug("TaskService: Created subtask '\(title)' under task \(parentTaskId)", category: .api)
            return subtask
        } catch {
            throw ErrorHandler.shared.handle(error, context: "Creating subtask")
        }
    }
    
    /// Complete a subtask
    func completeSubtask(listId: Int, subtaskId: Int) async throws -> TaskDTO {
        do {
            let subtask: TaskDTO = try await apiClient.request(
                "PATCH",
                API.Lists.taskAction(String(listId), String(subtaskId), "complete"),
                body: nil as String?
            )
            Logger.debug("TaskService: Completed subtask \(subtaskId)", category: .api)
            return subtask
        } catch {
            throw ErrorHandler.shared.handle(error, context: "Completing subtask")
        }
    }
    
    /// Reopen a subtask
    func reopenSubtask(listId: Int, subtaskId: Int) async throws -> TaskDTO {
        do {
            let subtask: TaskDTO = try await apiClient.request(
                "PATCH",
                API.Lists.taskAction(String(listId), String(subtaskId), "reopen"),
                body: nil as String?
            )
            Logger.debug("TaskService: Reopened subtask \(subtaskId)", category: .api)
            return subtask
        } catch {
            throw ErrorHandler.shared.handle(error, context: "Reopening subtask")
        }
    }
    
    /// Delete a subtask
    func deleteSubtask(listId: Int, subtaskId: Int) async throws {
        do {
            _ = try await apiClient.request(
                "DELETE",
                API.Lists.task(String(listId), String(subtaskId)),
                body: nil as String?
            ) as EmptyResponse
            Logger.debug("TaskService: Deleted subtask \(subtaskId)", category: .api)
        } catch {
            throw ErrorHandler.shared.handle(error, context: "Deleting subtask")
        }
    }
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
    let task: SubtaskData
    struct SubtaskData: Encodable {
        let title: String
        let parent_task_id: Int
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
