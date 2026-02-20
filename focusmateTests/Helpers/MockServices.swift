@testable import focusmate
import Foundation

// MARK: - MockTaskService

@MainActor
final class MockTaskService {
  private let apiClient: APIClient
  private let sideEffects: TaskSideEffectHandling

  var fetchTasksResult: Result<[TaskDTO], Error> = .success([])
  var fetchTaskResult: Result<TaskDTO, Error>?
  var createTaskResult: Result<TaskDTO, Error>?
  var updateTaskResult: Result<TaskDTO, Error>?
  var deleteTaskResult: Result<Void, Error> = .success(())
  var completeTaskResult: Result<TaskDTO, Error>?
  var reopenTaskResult: Result<TaskDTO, Error>?

  private(set) var fetchTasksCalled = false
  private(set) var fetchTasksListId: Int?
  private(set) var createTaskCalled = false
  private(set) var createTaskTitle: String?
  private(set) var updateTaskCalled = false
  private(set) var deleteTaskCalled = false
  private(set) var deleteTaskId: Int?
  private(set) var completeTaskCalled = false
  private(set) var reopenTaskCalled = false
  private(set) var reopenTaskId: Int?

  init(apiClient: APIClient, sideEffects: TaskSideEffectHandling) {
    self.apiClient = apiClient
    self.sideEffects = sideEffects
  }

  func fetchTasks(listId: Int) async throws -> [TaskDTO] {
    self.fetchTasksCalled = true
    self.fetchTasksListId = listId
    return try self.fetchTasksResult.get()
  }

  func fetchTask(listId: Int, taskId: Int) async throws -> TaskDTO {
    guard let result = fetchTaskResult else {
      return TestFactories.makeSampleTask(id: taskId, listId: listId)
    }
    return try result.get()
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
    self.createTaskCalled = true
    self.createTaskTitle = title
    if let result = createTaskResult {
      return try result.get()
    }
    return TestFactories.makeSampleTask(id: Int.random(in: 100 ... 999), listId: listId, title: title)
  }

  func updateTask(
    listId: Int,
    taskId: Int,
    title: String?,
    note: String?,
    dueAt: String?,
    color: String? = nil,
    priority: TaskPriority? = nil,
    starred: Bool? = nil,
    tagIds: [Int]? = nil
  ) async throws -> TaskDTO {
    self.updateTaskCalled = true
    if let result = updateTaskResult {
      return try result.get()
    }
    return TestFactories.makeSampleTask(id: taskId, listId: listId, title: title ?? "Updated")
  }

  func deleteTask(listId: Int, taskId: Int) async throws {
    self.deleteTaskCalled = true
    self.deleteTaskId = taskId
    try self.deleteTaskResult.get()
  }

  func completeTask(listId: Int, taskId: Int, reason: String? = nil) async throws -> TaskDTO {
    self.completeTaskCalled = true
    if let result = completeTaskResult {
      return try result.get()
    }
    return TestFactories.makeSampleTask(id: taskId, listId: listId, completedAt: Date().ISO8601Format())
  }

  func reopenTask(listId: Int, taskId: Int) async throws -> TaskDTO {
    self.reopenTaskCalled = true
    self.reopenTaskId = taskId
    if let result = reopenTaskResult {
      return try result.get()
    }
    return TestFactories.makeSampleTask(id: taskId, listId: listId)
  }

  func createSubtask(listId: Int, parentTaskId: Int, title: String) async throws -> SubtaskDTO {
    return TestFactories.makeSampleSubtask(parentTaskId: parentTaskId, title: title)
  }

  func updateSubtask(listId: Int, parentTaskId: Int, subtaskId: Int, title: String) async throws -> SubtaskDTO {
    return TestFactories.makeSampleSubtask(id: subtaskId, parentTaskId: parentTaskId, title: title)
  }
}

// MARK: - MockListService

@MainActor
final class MockListService {
  var fetchListsResult: Result<[ListDTO], Error> = .success([])
  var deleteListResult: Result<Void, Error> = .success(())

  private(set) var fetchListsCalled = false
  private(set) var deleteListCalled = false
  private(set) var deletedListId: Int?

  func fetchLists() async throws -> [ListDTO] {
    self.fetchListsCalled = true
    return try self.fetchListsResult.get()
  }

  func fetchList(id: Int) async throws -> ListDTO {
    return TestFactories.makeSampleList(id: id)
  }

  func createList(name: String, description: String?, color: String = "blue") async throws -> ListDTO {
    return TestFactories.makeSampleList(name: name, description: description, color: color)
  }

  func updateList(id: Int, name: String?, description: String?, color: String? = nil) async throws -> ListDTO {
    return TestFactories.makeSampleList(id: id, name: name ?? "Updated", description: description, color: color)
  }

  func deleteList(id: Int) async throws {
    self.deleteListCalled = true
    self.deletedListId = id
    try self.deleteListResult.get()
  }
}

// MARK: - MockTagService

@MainActor
final class MockTagService {
  var fetchTagsResult: Result<[TagDTO], Error> = .success([])

  private(set) var fetchTagsCalled = false

  func fetchTags() async throws -> [TagDTO] {
    self.fetchTagsCalled = true
    return try self.fetchTagsResult.get()
  }

  func createTag(name: String, color: String?) async throws -> TagDTO {
    return TagDTO(id: Int.random(in: 100 ... 999), name: name, color: color, tasks_count: 0, created_at: nil)
  }
}

// MARK: - MockEscalationService

@Observable
@MainActor
final class MockEscalationService {
  var isInGracePeriod: Bool = false
  var gracePeriodEndTime: Date?
  var overdueTaskIds: Set<Int> = []

  private(set) var taskBecameOverdueCalled = false
  private(set) var taskCompletedCalled = false
  private(set) var resetAllCalled = false

  func taskBecameOverdue(_ task: TaskDTO) {
    self.taskBecameOverdueCalled = true
    self.overdueTaskIds.insert(task.id)
  }

  func taskCompleted(_ taskId: Int) {
    self.taskCompletedCalled = true
    self.overdueTaskIds.remove(taskId)
  }

  func resetAll() {
    self.resetAllCalled = true
    self.isInGracePeriod = false
    self.gracePeriodEndTime = nil
    self.overdueTaskIds.removeAll()
  }

  var gracePeriodRemaining: TimeInterval? {
    guard let endTime = gracePeriodEndTime else { return nil }
    let remaining = endTime.timeIntervalSinceNow
    return remaining > 0 ? remaining : nil
  }

  var gracePeriodRemainingFormatted: String? {
    guard let remaining = gracePeriodRemaining else { return nil }
    let minutes = Int(remaining / 60)
    let hours = minutes / 60
    let mins = minutes % 60

    if hours > 0 {
      return "\(hours)h \(mins)m"
    } else {
      return "\(mins)m"
    }
  }
}

// MARK: - MockScreenTimeService

@MainActor
final class MockScreenTimeService: ScreenTimeManaging {
  var isBlocking = false
  var isAuthorized = true
  var hasSelections = true

  private(set) var startBlockingCalled = false
  private(set) var stopBlockingCalled = false
  private(set) var requestAuthorizationCalled = false
  private(set) var updateAuthorizationStatusCalled = false

  func startBlocking() {
    self.startBlockingCalled = true
    self.isBlocking = true
  }

  func stopBlocking() {
    self.stopBlockingCalled = true
    self.isBlocking = false
  }

  func requestAuthorization() async throws {
    self.requestAuthorizationCalled = true
    self.isAuthorized = true
  }

  func updateAuthorizationStatus() {
    self.updateAuthorizationStatusCalled = true
  }
}

// MARK: - MockNotificationService

@MainActor
final class MockNotificationService {
  private(set) var scheduleMorningBriefingCalled = false
  private(set) var morningBriefingTaskCount: Int?
  private(set) var cancelledTaskIds: [Int] = []

  func scheduleMorningBriefing(taskCount: Int) {
    self.scheduleMorningBriefingCalled = true
    self.morningBriefingTaskCount = taskCount
  }

  func cancelTaskNotifications(for taskId: Int) {
    self.cancelledTaskIds.append(taskId)
  }

  func scheduleEscalationNotification(id: String, title: String, body: String, date: Date) {
    // No-op for tests
  }
}

// MARK: - MockTodayService

@MainActor
final class MockTodayService {
  var fetchTodayResult: Result<TodayResponse, Error>?

  private(set) var fetchTodayCalled = false

  func fetchToday(ignoreCache: Bool = false) async throws -> TodayResponse {
    self.fetchTodayCalled = true
    if let result = fetchTodayResult {
      return try result.get()
    }
    return TodayResponse(
      overdue: [],
      has_more_overdue: nil,
      due_today: [],
      completed_today: [],
      stats: TodayStats(
        overdue_count: 0,
        due_today_count: 0,
        completed_today_count: 0,
        remaining_today: nil,
        completion_percentage: nil
      ),
      streak: nil
    )
  }

  func invalidateCache() async {}
}
