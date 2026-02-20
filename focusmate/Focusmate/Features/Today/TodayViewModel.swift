import Combine
import Foundation
import SwiftUI

@MainActor
@Observable
final class TodayViewModel {
  let taskService: TaskService
  let listService: ListService
  let tagService: TagService
  let escalationService: EscalationService
  let screenTimeService: any ScreenTimeManaging
  private let notificationService: NotificationService
  private let subtaskManager: SubtaskManager
  private var todayService: TodayService?
  private let apiClient: APIClient
  private var cancellables = Set<AnyCancellable>()

  var todayData: TodayResponse?
  var isLoading = true
  var error: FocusmateError?
  var nudgeMessage: String?
  var hideCompleted: Bool {
    didSet { AppSettings.shared.hideCompletedToday = self.hideCompleted }
  }

  var onOverdueCountChange: ((Int) -> Void)?
  private var inFlightTaskIds = Set<Int>()
  private var loadVersion = 0

  // MARK: - Computed Properties

  var totalTasks: Int {
    guard let data = todayData else { return 0 }
    return data.overdue.count + data.due_today.count + data.completed_today.count
  }

  var completedCount: Int {
    self.todayData?.completed_today.count ?? 0
  }

  var progress: Double {
    guard self.totalTasks > 0 else { return 0 }
    return Double(self.completedCount) / Double(self.totalTasks)
  }

  var isAllComplete: Bool {
    guard let data = todayData else { return false }
    return data.overdue.isEmpty && data.due_today.isEmpty && !data.completed_today.isEmpty
  }

  struct GroupedTasks {
    var anytime: [TaskDTO] = []
    var morning: [TaskDTO] = []
    var afternoon: [TaskDTO] = []
    var evening: [TaskDTO] = []
  }

  private(set) var groupedTasks = GroupedTasks()

  // MARK: - Private Helpers

  /// Recompute the time-of-day grouping from todayData.
  /// Called once per data load instead of on every body evaluation — avoids
  /// redundant O(n) Calendar lookups during SwiftUI render cycles.
  private func recomputeGroupedTasks() {
    guard let data = todayData else {
      self.groupedTasks = GroupedTasks()
      return
    }
    var anytime: [TaskDTO] = [], morning: [TaskDTO] = []
    var afternoon: [TaskDTO] = [], evening: [TaskDTO] = []
    let calendar = Calendar.current
    for task in data.due_today {
      guard let dueDate = task.dueDate else { anytime.append(task); continue }
      let components = calendar.dateComponents([.hour, .minute], from: dueDate)
      let hour = components.hour ?? 0
      let minute = components.minute ?? 0
      if hour == 0, minute == 0 { anytime.append(task) }
      else if hour < 12 { morning.append(task) }
      else if hour < 17 { afternoon.append(task) }
      else { evening.append(task) }
    }
    self.groupedTasks = GroupedTasks(anytime: anytime, morning: morning, afternoon: afternoon, evening: evening)
  }

  // MARK: - Timezone Guard

  /// Remove tasks that clearly don't belong to "today" in the device timezone.
  ///
  /// **Design choice — guard, not re-bucket.**  The server owns bucketing logic
  /// (overdue vs. due_today, grace periods, etc.).  Re-implementing that here
  /// creates two sources of truth that drift apart.  Instead, this method only
  /// *removes* tasks whose calendar day is clearly wrong — tomorrow or later
  /// leaked into due_today, or future-dated tasks leaked into overdue.  The
  /// server's internal split between overdue and due_today is preserved.
  ///
  /// **What this catches:** The server computes "start of today" from the
  /// `users.timezone` column.  If the device is UTC-5 but the server thinks
  /// UTC, the server's midnight is 5 hours ahead.  A task due tomorrow in the
  /// user's timezone might slip through as "due today" server-side.  This guard
  /// strips those leaks without re-inventing overdue logic.
  ///
  /// **What this deliberately does NOT do:**
  /// - Move tasks between overdue ↔ due_today (server's call)
  /// - Re-define "overdue" with client-side time checks
  /// - Touch completed_today (completion timestamps are authoritative)
  ///
  /// **Tradeoff:** If the server sends a task that's *actually* today in the
  /// user's TZ but falls on a different calendar day due to rounding, this
  /// guard could remove it.  Layers 1+2 (timezone sync + query param) make
  /// that window extremely narrow.
  private func removeOutOfDayTasks(_ response: TodayResponse) -> TodayResponse {
    let calendar = Calendar.current
    let startOfToday = calendar.startOfDay(for: Date())
    guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
      return response
    }

    func belongsToTodayOrEarlier(_ task: TaskDTO) -> Bool {
      guard let dueDate = task.dueDate else { return true }
      let taskDay = calendar.startOfDay(for: dueDate)
      return taskDay < startOfTomorrow
    }

    func belongsToTodayOrEarlierForOverdue(_ task: TaskDTO) -> Bool {
      guard let dueDate = task.dueDate else { return true }
      let taskDay = calendar.startOfDay(for: dueDate)
      // Overdue tasks should be today or earlier — reject future tasks
      return taskDay < startOfTomorrow
    }

    let filteredOverdue = response.overdue.filter { belongsToTodayOrEarlierForOverdue($0) }
    let filteredDueToday = response.due_today.filter { belongsToTodayOrEarlier($0) }

    // Only rebuild stats if we actually removed something
    if filteredOverdue.count == response.overdue.count,
       filteredDueToday.count == response.due_today.count
    {
      return response
    }

    return TodayResponse(
      overdue: filteredOverdue,
      has_more_overdue: response.has_more_overdue,
      due_today: filteredDueToday,
      completed_today: response.completed_today,
      stats: TodayStats(
        overdue_count: filteredOverdue.count,
        due_today_count: filteredDueToday.count,
        completed_today_count: response.completed_today.count,
        remaining_today: nil,
        completion_percentage: nil
      ),
      streak: response.streak
    )
  }

  // MARK: - Init

  init(
    taskService: TaskService,
    listService: ListService,
    tagService: TagService,
    apiClient: APIClient,
    subtaskManager: SubtaskManager,
    escalationService: EscalationService? = nil,
    screenTimeService: (any ScreenTimeManaging)? = nil,
    notificationService: NotificationService? = nil
  ) {
    self.taskService = taskService
    self.listService = listService
    self.tagService = tagService
    self.apiClient = apiClient
    self.subtaskManager = subtaskManager
    self.escalationService = escalationService ?? .shared
    self.screenTimeService = screenTimeService ?? ScreenTimeService.shared
    self.notificationService = notificationService ?? .shared
    self.hideCompleted = AppSettings.shared.hideCompletedToday

    // Subscribe to subtask changes and reload data.
    // Debounce coalesces rapid-fire subtask mutations (e.g. toggling several
    // checkboxes quickly) into a single API reload, preventing redundant
    // concurrent fetches that could race and show stale data.
    subtaskManager.changePublisher
      .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
      .sink { [weak self] _ in
        guard let self else { return }
        Task { await self.loadToday() }
      }
      .store(in: &self.cancellables)
  }

  // MARK: - Actions

  func initializeServiceIfNeeded() {
    if self.todayService == nil {
      self.todayService = TodayService(api: self.apiClient)
    }
  }

  /// Load today data, using a version counter to discard stale responses.
  ///
  /// Two overlapping calls (e.g. pull-to-refresh during a debounced subtask
  /// reload) race at the await point. Without protection, whichever API
  /// response arrives last writes todayData — if the older call finishes
  /// second, it overwrites fresher data. The version counter ensures only
  /// the most recent call's result is applied; superseded calls bail out
  /// silently after the await.
  func loadToday() async {
    guard let todayService else { return }

    self.loadVersion += 1
    let myVersion = self.loadVersion

    self.isLoading = self.todayData == nil
    self.error = nil

    do {
      let raw = try await todayService.fetchToday()
      guard myVersion == self.loadVersion else { return }
      let data = self.removeOutOfDayTasks(raw)
      self.todayData = data
      self.recomputeGroupedTasks()
      self.onOverdueCountChange?(self.todayData?.stats?.overdue_count ?? 0)

      let totalDueToday = (todayData?.stats?.due_today_count ?? 0) + (self.todayData?.stats?.overdue_count ?? 0)
      self.notificationService.scheduleMorningBriefing(taskCount: totalDueToday)
    } catch {
      guard myVersion == self.loadVersion else { return }
      self.error = ErrorHandler.shared.handle(error, context: "Loading Today")
    }

    guard myVersion == self.loadVersion else { return }
    self.isLoading = false
  }

  /// Invalidate cached today data and reload fresh from server.
  /// Called after mutations to ensure cache coherence (write invalidates read cache).
  private func reloadAfterMutation() async {
    await self.todayService?.invalidateCache()
    await self.loadToday()
  }

  func toggleComplete(_ task: TaskDTO, reason: String? = nil) async {
    guard self.inFlightTaskIds.insert(task.id).inserted else { return }
    defer { inFlightTaskIds.remove(task.id) }

    // Snapshot for rollback
    let snapshot = self.todayData

    if task.isCompleted {
      // Optimistic: move from completed back to due_today
      self.applyOptimisticReopen(task)

      do {
        _ = try await self.taskService.reopenTask(listId: task.list_id, taskId: task.id)
        await self.reloadAfterMutation()
      } catch let caughtError where NetworkMonitor.isOfflineError(caughtError) {
        let svc = self.taskService
        let listId = task.list_id, taskId = task.id
        await MutationQueue.shared.enqueue(description: "Reopen task") {
          _ = try await svc.reopenTask(listId: listId, taskId: taskId)
        }
      } catch {
        self.todayData = snapshot
        self.recomputeGroupedTasks()
        Logger.error("Failed to reopen task", error: error, category: .api)
        self.error = ErrorHandler.shared.handle(error, context: "Reopening task")
      }
    } else {
      // Optimistic: move from due_today/overdue to completed
      self.applyOptimisticComplete(task)
      HapticManager.success()

      do {
        _ = try await self.taskService.completeTask(listId: task.list_id, taskId: task.id, reason: reason)
        await self.reloadAfterMutation()
      } catch let caughtError where NetworkMonitor.isOfflineError(caughtError) {
        let svc = self.taskService
        let listId = task.list_id, taskId = task.id
        await MutationQueue.shared.enqueue(description: "Complete task") {
          _ = try await svc.completeTask(listId: listId, taskId: taskId, reason: reason)
        }
      } catch {
        self.todayData = snapshot
        self.recomputeGroupedTasks()
        Logger.error("Failed to complete task", error: error, category: .api)
        self.error = ErrorHandler.shared.handle(error, context: "Completing task")
      }
    }
  }

  // MARK: - Optimistic Updates

  /// Move a task from due_today/overdue to completed_today locally.
  /// The server is the source of truth — this is a UI-only update to
  /// make the app feel responsive. The subsequent reloadAfterMutation()
  /// will reconcile with the server state.
  private func applyOptimisticComplete(_ task: TaskDTO) {
    guard var data = todayData else { return }
    var completedTask = task
    completedTask.completed_at = ISO8601Utils.formatDateNoFrac(Date())
    data.overdue.removeAll { $0.id == task.id }
    data.due_today.removeAll { $0.id == task.id }
    data.completed_today.insert(completedTask, at: 0)
    self.todayData = data
    self.recomputeGroupedTasks()
    self.onOverdueCountChange?(data.overdue.count)
  }

  /// Move a task from completed_today back to due_today locally.
  private func applyOptimisticReopen(_ task: TaskDTO) {
    guard var data = todayData else { return }
    var reopenedTask = task
    reopenedTask.completed_at = nil
    data.completed_today.removeAll { $0.id == task.id }
    data.due_today.append(reopenedTask)
    self.todayData = data
    self.recomputeGroupedTasks()
  }

  func deleteTask(_ task: TaskDTO) async {
    guard self.inFlightTaskIds.insert(task.id).inserted else { return }
    defer { inFlightTaskIds.remove(task.id) }

    // Optimistic: remove the task from all arrays immediately
    let snapshot = self.todayData
    if var data = todayData {
      data.overdue.removeAll { $0.id == task.id }
      data.due_today.removeAll { $0.id == task.id }
      data.completed_today.removeAll { $0.id == task.id }
      self.todayData = data
      self.recomputeGroupedTasks()
    }

    do {
      try await self.taskService.deleteTask(listId: task.list_id, taskId: task.id)
      await self.reloadAfterMutation()
    } catch let caughtError where NetworkMonitor.isOfflineError(caughtError) {
      let svc = self.taskService
      let listId = task.list_id, taskId = task.id
      await MutationQueue.shared.enqueue(description: "Delete task") {
        try await svc.deleteTask(listId: listId, taskId: taskId)
      }
    } catch {
      self.todayData = snapshot
      self.recomputeGroupedTasks()
      Logger.error("Failed to delete task", error: error, category: .api)
      self.error = ErrorHandler.shared.handle(error, context: "Deleting task")
    }
  }

  func toggleStar(_ task: TaskDTO) async {
    guard self.inFlightTaskIds.insert(task.id).inserted else { return }
    defer { inFlightTaskIds.remove(task.id) }

    do {
      _ = try await self.taskService.updateTask(
        listId: task.list_id,
        taskId: task.id,
        title: nil,
        note: nil,
        dueAt: nil,
        starred: !task.isStarred
      )
      HapticManager.light()
      await self.reloadAfterMutation()
    } catch {
      Logger.error("Failed to toggle star", error: error, category: .api)
      self.error = ErrorHandler.shared.handle(error, context: "Starring task")
    }
  }

  func nudgeTask(_ task: TaskDTO) async {
    let cooldown = NudgeCooldownManager.shared
    guard !cooldown.isOnCooldown(taskId: task.id) else {
      withAnimation {
        self.nudgeMessage = "Already nudged recently"
      }
      return
    }

    do {
      try await self.taskService.nudgeTask(listId: task.list_id, taskId: task.id)
      cooldown.recordNudge(taskId: task.id)
      HapticManager.success()
      withAnimation {
        self.nudgeMessage = "Nudge sent!"
      }
    } catch let error as FocusmateError where error.isRateLimited {
      cooldown.recordNudge(taskId: task.id)
      withAnimation {
        self.nudgeMessage = "Already nudged recently"
      }
    } catch {
      Logger.error("Failed to nudge: \(error)", category: .api)
      HapticManager.error()
      withAnimation {
        self.nudgeMessage = "Couldn't send nudge"
      }
    }
  }

  // MARK: - Subtask Actions

  func createSubtask(parentTask: TaskDTO, title: String) async {
    do {
      _ = try await self.subtaskManager.create(parentTask: parentTask, title: title)
      // loadToday() is triggered automatically via changePublisher subscription
    } catch {
      Logger.error("Failed to create subtask", error: error, category: .api)
      self.error = ErrorHandler.shared.handle(error, context: "Creating subtask")
      HapticManager.error()
    }
  }

  func updateSubtask(info: SubtaskEditInfo, title: String) async {
    do {
      _ = try await self.subtaskManager.update(subtask: info.subtask, parentTask: info.parentTask, title: title)
      // loadToday() is triggered automatically via changePublisher subscription
    } catch {
      Logger.error("Failed to update subtask", error: error, category: .api)
      self.error = ErrorHandler.shared.handle(error, context: "Updating subtask")
      HapticManager.error()
    }
  }
}
