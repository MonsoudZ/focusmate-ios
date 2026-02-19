import Foundation

/// Service for task and subtask CRUD operations
///
/// Design concept: This is a **Repository pattern** implementation - it abstracts
/// the data access layer (API) from the domain logic. All API calls go through
/// this service, which handles validation, error transformation, and side effects.
///
/// The service uses **optimistic side effects** - it notifies observers immediately
/// on success rather than waiting for a round-trip confirmation. This provides
/// snappier UI updates at the cost of potential consistency issues if the operation
/// fails after notification.
final class TaskService {
  let apiClient: APIClient
  private let sideEffects: TaskSideEffectHandling

  init(apiClient: APIClient, sideEffects: TaskSideEffectHandling) {
    self.apiClient = apiClient
    self.sideEffects = sideEffects
  }

  // MARK: - Task Operations

  func fetchTasks(listId: Int) async throws -> [TaskDTO] {
    try InputValidation.requirePositive(listId, fieldName: "list_id")
    let response: TasksResponse = try await apiClient.request(
      "GET",
      API.Lists.tasks(String(listId)),
      body: nil as String?
    )
    return response.tasks
  }

  func fetchTask(listId: Int, taskId: Int) async throws -> TaskDTO {
    try InputValidation.requirePositive(listId, fieldName: "list_id")
    try InputValidation.requirePositive(taskId, fieldName: "task_id")
    let response: SingleTaskResponse = try await apiClient.request(
      "GET",
      API.Lists.task(String(listId), String(taskId)),
      body: nil as String?
    )
    return response.task
  }

  /// Fetch a task by ID without knowing the list ID (for deep links)
  func fetchTaskById(_ taskId: Int) async throws -> TaskDTO {
    try InputValidation.requirePositive(taskId, fieldName: "task_id")
    let response: SingleTaskResponse = try await apiClient.request(
      "GET",
      API.Tasks.id(String(taskId)),
      body: nil as String?
    )
    return response.task
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
    try InputValidation.requirePositive(listId, fieldName: "list_id")
    try InputValidation.requireNotEmpty(title, fieldName: "title")
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

    await MainActor.run { self.sideEffects.taskCreated(response.task, isSubtask: parentTaskId != nil) }

    return response.task
  }

  func updateTask(
    listId: Int, taskId: Int, title: String?, note: String?, dueAt: String?,
    color: String? = nil, priority: TaskPriority? = nil, starred: Bool? = nil,
    hidden: Bool? = nil, tagIds: [Int]? = nil
  ) async throws -> TaskDTO {
    try InputValidation.requirePositive(listId, fieldName: "list_id")
    try InputValidation.requirePositive(taskId, fieldName: "task_id")
    if let title, title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      throw FocusmateError.validation(["title": ["cannot be empty"]], nil)
    }
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

    await MainActor.run { self.sideEffects.taskUpdated(response.task) }

    return response.task
  }

  /// Deletes a task from the server, then updates local state on success.
  ///
  /// ## Consistency Guarantee
  /// The API call executes BEFORE updating local state. This ensures:
  /// - If network fails, UI remains unchanged (task still visible)
  /// - User can retry the delete without confusion
  /// - Server and client state stay synchronized
  ///
  /// ## Tradeoff
  /// Slightly slower perceived response (network round-trip before UI update).
  /// Previous "optimistic" approach updated UI first, but had no rollback on
  /// failure, causing tasks to disappear from UI while still existing on server.
  func deleteTask(listId: Int, taskId: Int) async throws {
    try InputValidation.requirePositive(listId, fieldName: "list_id")
    try InputValidation.requirePositive(taskId, fieldName: "task_id")
    // API call FIRST - ensure server accepts the delete
    _ = try await self.apiClient.request(
      "DELETE",
      API.Lists.task(String(listId), String(taskId)),
      body: nil as String?
    ) as EmptyResponse

    // Only update local state after confirmed server deletion
    await MainActor.run { self.sideEffects.taskDeleted(taskId: taskId) }
  }

  func rescheduleTask(listId: Int, taskId: Int, newDueAt: String, reason: String) async throws -> TaskDTO {
    try InputValidation.requirePositive(listId, fieldName: "list_id")
    try InputValidation.requirePositive(taskId, fieldName: "task_id")

    let request = RescheduleTaskRequest(new_due_at: newDueAt, reason: reason)
    let response: SingleTaskResponse = try await apiClient.request(
      "POST",
      API.Lists.taskAction(String(listId), String(taskId), "reschedule"),
      body: request
    )
    await MainActor.run { self.sideEffects.taskUpdated(response.task) }
    return response.task
  }

  func completeTask(listId: Int, taskId: Int, reason: String? = nil) async throws -> TaskDTO {
    try InputValidation.requirePositive(listId, fieldName: "list_id")
    try InputValidation.requirePositive(taskId, fieldName: "task_id")
    // Only include reason if it's non-empty after trimming
    let trimmedReason = reason?.trimmingCharacters(in: .whitespacesAndNewlines)
    let body: CompleteTaskRequest? = trimmedReason.flatMap { $0.isEmpty ? nil : CompleteTaskRequest(missed_reason: $0) }
    let response: SingleTaskResponse = try await apiClient.request(
      "PATCH",
      API.Lists.taskAction(String(listId), String(taskId), "complete"),
      body: body
    )

    await MainActor.run { self.sideEffects.taskCompleted(taskId: taskId) }

    return response.task
  }

  func reopenTask(listId: Int, taskId: Int) async throws -> TaskDTO {
    try InputValidation.requirePositive(listId, fieldName: "list_id")
    try InputValidation.requirePositive(taskId, fieldName: "task_id")
    let response: SingleTaskResponse = try await apiClient.request(
      "PATCH",
      API.Lists.taskAction(String(listId), String(taskId), "reopen"),
      body: nil as String?
    )

    await MainActor.run { self.sideEffects.taskReopened(response.task) }

    return response.task
  }

  func reorderTasks(listId: Int, tasks: [(id: Int, position: Int)]) async throws {
    try InputValidation.requirePositive(listId, fieldName: "list_id")
    let request = ReorderTasksRequest(tasks: tasks.map { ReorderTask(id: $0.id, position: $0.position) })
    _ = try await self.apiClient.request(
      "POST",
      API.Lists.tasksReorder(String(listId)),
      body: request
    ) as EmptyResponse
  }

  func searchTasks(query: String) async throws -> [TaskDTO] {
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedQuery.isEmpty else {
      return []
    }
    let response: TasksResponse = try await apiClient.request(
      "GET",
      API.Tasks.search,
      body: nil as String?,
      queryParameters: ["q": trimmedQuery]
    )
    return response.tasks
  }

  // MARK: - Subtask Methods

  /// Create a subtask under a parent task
  func createSubtask(listId: Int, parentTaskId: Int, title: String) async throws -> SubtaskDTO {
    try self.validateSubtaskContext(listId: listId, parentTaskId: parentTaskId)
    try InputValidation.requireNotEmpty(title, fieldName: "title")
    let request = CreateSubtaskRequest(subtask: .init(title: title))
    let response: SubtaskResponse = try await apiClient.request(
      "POST",
      API.Lists.subtasks(String(listId), String(parentTaskId)),
      body: request
    )
    Logger.debug("TaskService: Created subtask '\(title)' under task \(parentTaskId)", category: .api)
    return response.subtask
  }

  /// Complete a subtask
  func completeSubtask(listId: Int, parentTaskId: Int, subtaskId: Int) async throws -> SubtaskDTO {
    try await self.performSubtaskAction(
      listId: listId,
      parentTaskId: parentTaskId,
      subtaskId: subtaskId,
      action: "complete"
    )
  }

  /// Reopen a subtask
  func reopenSubtask(listId: Int, parentTaskId: Int, subtaskId: Int) async throws -> SubtaskDTO {
    try await self.performSubtaskAction(
      listId: listId,
      parentTaskId: parentTaskId,
      subtaskId: subtaskId,
      action: "reopen"
    )
  }

  /// Update a subtask
  func updateSubtask(listId: Int, parentTaskId: Int, subtaskId: Int, title: String) async throws -> SubtaskDTO {
    try self.validateSubtaskContext(listId: listId, parentTaskId: parentTaskId, subtaskId: subtaskId)
    try InputValidation.requireNotEmpty(title, fieldName: "title")
    let request = UpdateSubtaskRequest(subtask: .init(title: title))
    let response: SubtaskResponse = try await apiClient.request(
      "PUT",
      API.Lists.subtask(String(listId), String(parentTaskId), String(subtaskId)),
      body: request
    )
    Logger.debug("TaskService: Updated subtask \(subtaskId)", category: .api)
    return response.subtask
  }

  /// Delete a subtask
  func deleteSubtask(listId: Int, parentTaskId: Int, subtaskId: Int) async throws {
    try self.validateSubtaskContext(listId: listId, parentTaskId: parentTaskId, subtaskId: subtaskId)
    _ = try await self.apiClient.request(
      "DELETE",
      API.Lists.subtask(String(listId), String(parentTaskId), String(subtaskId)),
      body: nil as String?
    ) as EmptyResponse
    Logger.debug("TaskService: Deleted subtask \(subtaskId)", category: .api)
  }

  // MARK: - Subtask Helpers

  private func validateSubtaskContext(listId: Int, parentTaskId: Int, subtaskId: Int? = nil) throws {
    try InputValidation.requirePositive(listId, fieldName: "list_id")
    try InputValidation.requirePositive(parentTaskId, fieldName: "task_id")
    if let subtaskId {
      try InputValidation.requirePositive(subtaskId, fieldName: "subtask_id")
    }
  }

  /// Performs a PATCH action (complete/reopen) on a subtask
  private func performSubtaskAction(
    listId: Int,
    parentTaskId: Int,
    subtaskId: Int,
    action: String
  ) async throws -> SubtaskDTO {
    try self.validateSubtaskContext(listId: listId, parentTaskId: parentTaskId, subtaskId: subtaskId)
    let response: SubtaskResponse = try await apiClient.request(
      "PATCH",
      API.Lists.subtaskAction(String(listId), String(parentTaskId), String(subtaskId), action),
      body: nil as String?
    )
    Logger.debug("TaskService: \(action.capitalized) subtask \(subtaskId)", category: .api)
    return response.subtask
  }

  // MARK: - Nudge

  func nudgeTask(listId: Int, taskId: Int) async throws {
    try InputValidation.requirePositive(listId, fieldName: "list_id")
    try InputValidation.requirePositive(taskId, fieldName: "task_id")
    let endpoint = API.Lists.taskAction(String(listId), String(taskId), "nudge")
    let _: NudgeResponse = try await apiClient.request("POST", endpoint, body: nil as String?)
    Logger.debug("TaskService: Nudged task \(taskId)", category: .api)
  }
}
