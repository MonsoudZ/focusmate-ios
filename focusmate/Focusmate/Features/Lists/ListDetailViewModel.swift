import Combine
import Foundation
import SwiftUI

@MainActor
@Observable
// swiftlint:disable:next type_body_length
final class ListDetailViewModel {
  let list: ListDTO
  let taskService: TaskService
  let listService: ListService
  let tagService: TagService
  let inviteService: InviteService
  let friendService: FriendService
  private let subtaskManager: SubtaskManager
  private var cancellables = Set<AnyCancellable>()

  // MARK: - Data

  var tasks: [TaskDTO] = [] {
    didSet { self.invalidateTaskGroupsCache() }
  }

  var isLoading = false
  var error: FocusmateError?

  // MARK: - Alerts

  var showingDeleteConfirmation = false

  // MARK: - UI

  var nudgeMessage: String?
  var hideCompleted: Bool {
    didSet {
      AppSettings.shared.hideCompletedInLists = self.hideCompleted
      self.invalidateTaskGroupsCache()
    }
  }

  // MARK: - Callback

  var onDismiss: (() -> Void)?

  // MARK: - Init

  init(
    list: ListDTO,
    taskService: TaskService,
    listService: ListService,
    tagService: TagService,
    inviteService: InviteService,
    friendService: FriendService,
    subtaskManager: SubtaskManager
  ) {
    self.list = list
    self.taskService = taskService
    self.listService = listService
    self.tagService = tagService
    self.inviteService = inviteService
    self.friendService = friendService
    self.subtaskManager = subtaskManager
    self.hideCompleted = AppSettings.shared.hideCompletedInLists

    // Subscribe to subtask changes and update local state
    // Guard ensures self is still alive before handling the change
    subtaskManager.changePublisher
      .sink { [weak self] change in
        guard let self else { return }
        self.handleSubtaskChange(change)
      }
      .store(in: &self.cancellables)
  }

  // MARK: - Subtask Change Handling

  private func handleSubtaskChange(_ change: SubtaskChange) {
    // Only handle changes for tasks in this list
    guard change.listId == self.list.id else { return }
    guard let taskIdx = tasks.firstIndex(where: { $0.id == change.parentTaskId }) else { return }

    switch change.type {
    case let .completed(subtask), let .reopened(subtask), let .updated(subtask):
      if var subs = tasks[taskIdx].subtasks,
         let subIdx = subs.firstIndex(where: { $0.id == subtask.id })
      {
        subs[subIdx] = subtask
        self.tasks[taskIdx].subtasks = subs
      }
    case let .created(subtask):
      var existing = self.tasks[taskIdx].subtasks ?? []
      existing.append(subtask)
      self.tasks[taskIdx].subtasks = existing
    case let .deleted(subtaskId):
      if var subs = tasks[taskIdx].subtasks {
        subs.removeAll { $0.id == subtaskId }
        self.tasks[taskIdx].subtasks = subs
      }
    }
  }

  // MARK: - Computed: Permissions

  var isOwner: Bool {
    self.list.role == "owner" || self.list.role == nil
  }

  var isEditor: Bool {
    self.list.role == "editor"
  }

  var isViewer: Bool {
    self.list.role == "viewer"
  }

  var canEdit: Bool {
    self.isOwner || self.isEditor
  }

  var isSharedList: Bool {
    self.list.role != nil
  }

  var roleLabel: String {
    switch self.list.role {
    case "owner": return "Owner"
    case "editor": return "Editor"
    case "viewer": return "Viewer"
    default: return self.list.role?.capitalized ?? "Member"
    }
  }

  var roleIcon: String {
    switch self.list.role {
    case "owner": return "crown.fill"
    case "editor": return DS.Icon.edit
    case "viewer": return "eye"
    default: return "person"
    }
  }

  var roleColor: Color {
    switch self.list.role {
    case "owner": return .yellow
    case "editor": return DS.Colors.accent
    default: return Color(.secondaryLabel)
    }
  }

  // MARK: - Computed: Task Groups

  //
  // Performance: Groups are computed in a single O(n) pass and cached.
  // Without caching, each computed property (urgent, starred, normal, completed)
  // would do its own filter+sort, causing O(4n log n) work per view render.
  // With 100 tasks at 60fps, that's 24,000 filter operations/second.
  //
  // Tradeoff: Manual cache invalidation required when `tasks` changes.
  // The cache key uses tasks.count as a simple change detector. For more
  // robust invalidation, we'd need to hash task IDs, but count is sufficient
  // for typical add/remove/complete operations.

  private var cachedGroups: TaskGroups?
  private var cacheVersion: Int = 0
  private var cachedVersion: Int = -1

  /// Call this after any modification to tasks array to invalidate the cache
  private func invalidateTaskGroupsCache() {
    self.cacheVersion += 1
  }

  private struct TaskGroups {
    var urgent: [TaskDTO]
    var starred: [TaskDTO]
    var normal: [TaskDTO]
    var completed: [TaskDTO]
  }

  private var taskGroups: TaskGroups {
    // Return cached if version hasn't changed
    if self.cachedVersion == self.cacheVersion, let cached = cachedGroups {
      return cached
    }

    // Single-pass grouping: O(n) instead of O(4n)
    var urgent: [TaskDTO] = []
    var starred: [TaskDTO] = []
    var normal: [TaskDTO] = []
    var completed: [TaskDTO] = []

    for task in self.tasks {
      guard !task.isSubtask else { continue }

      if task.isCompleted {
        completed.append(task)
      } else if task.taskPriority == .urgent {
        urgent.append(task)
      } else if task.isStarred {
        starred.append(task)
      } else {
        normal.append(task)
      }
    }

    // Sort each group by position: O(k log k) where k << n
    let sortByPosition: (TaskDTO, TaskDTO) -> Bool = {
      ($0.position ?? Int.max) < ($1.position ?? Int.max)
    }

    let groups = TaskGroups(
      urgent: urgent.sorted(by: sortByPosition),
      starred: starred.sorted(by: sortByPosition),
      normal: normal.sorted(by: sortByPosition),
      completed: completed.sorted(by: sortByPosition)
    )

    self.cachedGroups = groups
    self.cachedVersion = self.cacheVersion
    return groups
  }

  var urgentTasks: [TaskDTO] {
    self.taskGroups.urgent
  }

  var starredTasks: [TaskDTO] {
    self.taskGroups.starred
  }

  var normalTasks: [TaskDTO] {
    self.taskGroups.normal
  }

  var completedTasks: [TaskDTO] {
    self.hideCompleted ? [] : self.taskGroups.completed
  }

  var completedCount: Int {
    self.taskGroups.completed.count
  }

  // MARK: - Task Group Enum

  enum TaskGroup {
    case urgent, starred, normal
  }

  // MARK: - Actions

  private var loadVersion = 0

  /// Load tasks with version counter to discard stale responses.
  ///
  /// Same race as ListsViewModel: `.task` and `.refreshable` can overlap,
  /// and the older response arriving second would overwrite fresh data.
  func loadTasks() async {
    self.loadVersion += 1
    let myVersion = self.loadVersion

    self.isLoading = self.tasks.isEmpty
    self.error = nil

    do {
      let response = try await taskService.fetchTasks(listId: self.list.id)
      guard myVersion == self.loadVersion else { return }
      self.tasks = response
    } catch let err as FocusmateError {
      guard myVersion == loadVersion else { return }
      error = err
      HapticManager.error()
    } catch {
      guard myVersion == self.loadVersion else { return }
      self.error = ErrorHandler.shared.handle(error, context: "Loading tasks")
      HapticManager.error()
    }

    guard myVersion == self.loadVersion else { return }
    self.isLoading = false
  }

  func toggleStar(_ task: TaskDTO) async {
    guard self.canEdit else { return }

    let originalTasks = self.tasks
    if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
      self.tasks[idx].starred = !(self.tasks[idx].starred ?? false)
    }

    do {
      let updated = try await taskService.updateTask(
        listId: task.list_id,
        taskId: task.id,
        title: nil,
        note: nil,
        dueAt: nil,
        starred: !task.isStarred
      )
      if let idx = tasks.firstIndex(where: { $0.id == updated.id }) {
        self.tasks[idx] = updated
      }
    } catch {
      self.tasks = originalTasks
      Logger.error("Failed to toggle star: \(error)", category: .api)
      HapticManager.error()
    }
  }

  func toggleHidden(_ task: TaskDTO) async {
    guard self.canEdit else { return }

    let originalTasks = self.tasks
    if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
      self.tasks[idx].hidden = !(self.tasks[idx].hidden ?? false)
    }

    do {
      let updated = try await taskService.updateTask(
        listId: task.list_id,
        taskId: task.id,
        title: nil,
        note: nil,
        dueAt: nil,
        hidden: !task.isHidden
      )
      if let idx = tasks.firstIndex(where: { $0.id == updated.id }) {
        self.tasks[idx] = updated
      }
      HapticManager.selection()
    } catch {
      self.tasks = originalTasks
      Logger.error("Failed to toggle hidden: \(error)", category: .api)
      HapticManager.error()
    }
  }

  func toggleComplete(_ task: TaskDTO, reason: String? = nil) async {
    if task.isCompleted {
      let originalTasks = self.tasks
      if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
        self.tasks[idx].completed_at = nil
      }

      do {
        let updated = try await taskService.reopenTask(listId: self.list.id, taskId: task.id)
        HapticManager.light()
        if let idx = tasks.firstIndex(where: { $0.id == updated.id }) {
          self.tasks[idx] = updated
        }
      } catch let caughtError where NetworkMonitor.isOfflineError(caughtError) {
        HapticManager.light()
        let svc = self.taskService
        let listId = self.list.id, taskId = task.id
        await MutationQueue.shared.enqueue(description: "Reopen task") {
          _ = try await svc.reopenTask(listId: listId, taskId: taskId)
        }
      } catch {
        self.tasks = originalTasks
        self.error = ErrorHandler.shared.handle(error, context: "Reopening task")
        HapticManager.error()
      }
    } else {
      // Optimistic UI update
      let originalTasks = self.tasks
      if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
        self.tasks[idx].completed_at = ISO8601Utils.formatDateNoFrac(Date())
      }

      do {
        let updated = try await taskService.completeTask(listId: self.list.id, taskId: task.id, reason: reason)
        HapticManager.success()
        if let idx = tasks.firstIndex(where: { $0.id == updated.id }) {
          self.tasks[idx] = updated
        }
      } catch let caughtError where NetworkMonitor.isOfflineError(caughtError) {
        HapticManager.success()
        let svc = self.taskService
        let listId = self.list.id, taskId = task.id
        await MutationQueue.shared.enqueue(description: "Complete task") {
          _ = try await svc.completeTask(listId: listId, taskId: taskId, reason: reason)
        }
      } catch {
        self.tasks = originalTasks
        self.error = ErrorHandler.shared.handle(error, context: "Completing task")
        HapticManager.error()
      }
    }
  }

  /// Updates local task state to show as completed.
  /// Called by TaskRow's onComplete callback after TaskRow handles the API call.
  func markTaskCompleted(_ taskId: Int) {
    if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
      self.tasks[idx].completed_at = ISO8601Utils.formatDateNoFrac(Date())
    }
  }

  func deleteTask(_ task: TaskDTO) async {
    guard task.can_delete ?? self.canEdit else { return }

    let originalTasks = self.tasks
    self.tasks.removeAll { $0.id == task.id }
    HapticManager.medium()

    do {
      try await self.taskService.deleteTask(listId: self.list.id, taskId: task.id)
    } catch let caughtError where NetworkMonitor.isOfflineError(caughtError) {
      // Keep optimistic removal — will sync when online
      let svc = self.taskService
      let listId = self.list.id, taskId = task.id
      await MutationQueue.shared.enqueue(description: "Delete task") {
        try await svc.deleteTask(listId: listId, taskId: taskId)
      }
    } catch {
      self.tasks = originalTasks
      self.error = ErrorHandler.shared.handle(error, context: "Deleting task")
      HapticManager.error()
    }
  }

  func nudgeAboutTask(_ task: TaskDTO) async {
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
      // Local state is updated via changePublisher subscription
    } catch {
      Logger.error("Failed to create subtask: \(error)", category: .api)
      self.error = ErrorHandler.shared.handle(error, context: "Creating subtask")
      HapticManager.error()
    }
  }

  func updateSubtask(info: SubtaskEditInfo, title: String) async {
    do {
      _ = try await self.subtaskManager.update(subtask: info.subtask, parentTask: info.parentTask, title: title)
      // Local state is updated via changePublisher subscription
    } catch {
      Logger.error("Failed to update subtask: \(error)", category: .api)
      self.error = ErrorHandler.shared.handle(error, context: "Updating subtask")
      HapticManager.error()
    }
  }

  func reorderTasks(_ updates: [(id: Int, position: Int)], originalTasks: [TaskDTO]? = nil) async {
    do {
      try await self.taskService.reorderTasks(listId: self.list.id, tasks: updates)
    } catch {
      if let originalTasks {
        self.tasks = originalTasks
      }
      Logger.error("Failed to reorder tasks: \(error)", category: .api)
      self.error = ErrorHandler.shared.handle(error, context: "Reordering tasks")
      HapticManager.error()
    }
  }

  func moveTask(in group: TaskGroup, from source: IndexSet, to destination: Int) {
    guard self.canEdit else { return }

    var groupTasks: [TaskDTO] = switch group {
    case .urgent:
      self.urgentTasks
    case .starred:
      self.starredTasks
    case .normal:
      self.normalTasks
    }

    groupTasks.move(fromOffsets: source, toOffset: destination)

    let updates = groupTasks.enumerated().map { index, task in
      (id: task.id, position: index)
    }

    let originalTasks = self.tasks

    // Batch position updates into a single array replacement so that
    // tasks.didSet (→ invalidateTaskGroupsCache) fires exactly once.
    // The previous code mutated tasks[idx].position in a loop, triggering
    // didSet on every iteration. SwiftUI could re-render the ForEach
    // mid-loop with partially-updated positions, breaking the drag state.
    var updated = self.tasks
    for (id, position) in updates {
      if let idx = updated.firstIndex(where: { $0.id == id }) {
        updated[idx].position = position
      }
    }
    self.tasks = updated

    HapticManager.selection()

    Task {
      await self.reorderTasks(updates, originalTasks: originalTasks)
    }
  }

  func deleteList() async {
    do {
      try await self.listService.deleteList(id: self.list.id)
      HapticManager.medium()
      self.onDismiss?()
    } catch let caughtError where NetworkMonitor.isOfflineError(caughtError) {
      HapticManager.medium()
      let svc = self.listService
      let listId = self.list.id
      await MutationQueue.shared.enqueue(description: "Delete list") {
        try await svc.deleteList(id: listId)
      }
      self.onDismiss?()
    } catch {
      self.error = ErrorHandler.shared.handle(error, context: "Deleting list")
      HapticManager.error()
    }
  }
}

// MARK: - Subtask Edit Info

struct SubtaskEditInfo: Identifiable, Hashable {
  let id = UUID()
  let subtask: SubtaskDTO
  let parentTask: TaskDTO
}
