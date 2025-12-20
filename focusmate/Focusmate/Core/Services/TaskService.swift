import Foundation

final class TaskService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchTasks(listId: Int) async throws -> [TaskDTO] {
        let response: TasksResponse = try await apiClient.request(
            "GET",
            API.Lists.tasks(String(listId)),
            body: nil as String?
        )
        Logger.debug("TaskService: Fetched \(response.tasks.count) tasks", category: .api)
        return response.tasks
    }

    func fetchTask(listId: Int, taskId: Int) async throws -> TaskDTO {
        return try await apiClient.request(
            "GET",
            API.Lists.task(String(listId), String(taskId)),
            body: nil as String?
        )
    }

    func createTask(listId: Int, title: String, note: String?, dueAt: Date?) async throws -> TaskDTO {
        let request = CreateTaskRequest(task: .init(
            title: title,
            note: note,
            due_at: dueAt?.ISO8601Format()
        ))
        return try await apiClient.request(
            "POST",
            API.Lists.tasks(String(listId)),
            body: request
        )
    }

    func updateTask(listId: Int, taskId: Int, title: String?, note: String?, dueAt: String?) async throws -> TaskDTO {
        let request = UpdateTaskRequest(task: .init(
            title: title,
            note: note,
            due_at: dueAt
        ))
        return try await apiClient.request(
            "PUT",
            API.Lists.task(String(listId), String(taskId)),
            body: request
        )
    }

    func deleteTask(listId: Int, taskId: Int) async throws {
        _ = try await apiClient.request(
            "DELETE",
            API.Lists.task(String(listId), String(taskId)),
            body: nil as String?
        ) as EmptyResponse
    }

    func completeTask(listId: Int, taskId: Int) async throws -> TaskDTO {
        return try await apiClient.request(
            "PATCH",
            API.Lists.taskAction(String(listId), String(taskId), "complete"),
            body: nil as String?
        )
    }

    func reopenTask(listId: Int, taskId: Int) async throws -> TaskDTO {
        return try await apiClient.request(
            "PATCH",
            API.Lists.taskAction(String(listId), String(taskId), "reopen"),
            body: nil as String?
        )
    }

    func snoozeTask(listId: Int, taskId: Int, until: Date) async throws -> TaskDTO {
        let request = SnoozeRequest(snooze_until: until.ISO8601Format())
        return try await apiClient.request(
            "PATCH",
            API.Lists.taskAction(String(listId), String(taskId), "snooze"),
            body: request
        )
    }
}

// MARK: - Request Models (local to TaskService)

private struct CreateTaskRequest: Encodable {
    let task: TaskData
    struct TaskData: Encodable {
        let title: String
        let note: String?
        let due_at: String?
    }
}

private struct UpdateTaskRequest: Encodable {
    let task: TaskData
    struct TaskData: Encodable {
        let title: String?
        let note: String?
        let due_at: String?
    }
}

private struct SnoozeRequest: Encodable {
    let snooze_until: String
}
