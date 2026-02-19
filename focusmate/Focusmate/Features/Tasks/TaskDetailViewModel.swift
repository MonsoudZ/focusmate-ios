import Combine
import Foundation
import UIKit

@MainActor
@Observable
final class TaskDetailViewModel {
  // MARK: - State

  var showingDeleteConfirmation = false
  var error: FocusmateError?
  var isSubtasksExpanded = true
  var isRescheduleHistoryExpanded = false
  var showNudgeSent = false
  var showCopied = false
  var subtasks: [SubtaskDTO]

  // MARK: - Dependencies

  private(set) var task: TaskDTO
  let listName: String
  let listId: Int
  let onComplete: () async -> Void
  let onDelete: () async -> Void
  let onUpdate: () async -> Void
  let taskService: TaskService
  let tagService: TagService
  let subtaskManager: SubtaskManager
  let listService: ListService
  private let escalationService: EscalationService

  private var cancellables = Set<AnyCancellable>()
  private var nudgeToastDismissTask: Task<Void, Never>?
  private var copiedToastDismissTask: Task<Void, Never>?

  /// Duration for auto-dismissing toast messages (2 seconds)
  private static let toastDismissDuration: UInt64 = 2_000_000_000

  // MARK: - Computed Properties

  var isOverdue: Bool {
    self.task.isActuallyOverdue
  }

  var isTrackedForEscalation: Bool {
    self.escalationService.isTaskTracked(self.task.id)
  }

  /// Whether completing this task requires a reason (overdue or tracked for escalation)
  var requiresCompletionReason: Bool {
    self.isOverdue || self.isTrackedForEscalation
  }

  var canEdit: Bool {
    self.task.can_edit ?? true
  }

  var isSharedList = false
  var listMembers: [ListMemberDTO] = []

  var isSharedTask: Bool {
    self.isSharedList || self.task.creator != nil
  }

  var canNudge: Bool {
    self.isSharedList && !self.task.isCompleted
  }

  var canHide: Bool {
    self.isSharedTask && self.canEdit
  }

  var subtaskProgress: Double {
    guard !self.subtasks.isEmpty else { return 0 }
    let completed = self.subtasks.filter(\.isCompleted).count
    return Double(completed) / Double(self.subtasks.count)
  }

  var subtaskProgressText: String {
    let completed = self.subtasks.filter(\.isCompleted).count
    return "\(completed)/\(self.subtasks.count)"
  }

  var hasSubtasks: Bool {
    !self.subtasks.isEmpty
  }

  var hasRescheduleHistory: Bool {
    self.task.hasBeenRescheduled
  }

  var rescheduleCount: Int {
    self.task.rescheduleCount
  }

  var rescheduleEvents: [RescheduleEventDTO] {
    self.task.reschedule_events ?? []
  }

  // MARK: - Init

  init(
    task: TaskDTO,
    listName: String,
    listId: Int,
    taskService: TaskService,
    tagService: TagService,
    subtaskManager: SubtaskManager,
    listService: ListService,
    escalationService: EscalationService = .shared,
    onComplete: @escaping () async -> Void,
    onDelete: @escaping () async -> Void,
    onUpdate: @escaping () async -> Void
  ) {
    self.task = task
    self.listName = listName
    self.listId = listId
    self.taskService = taskService
    self.tagService = tagService
    self.subtaskManager = subtaskManager
    self.listService = listService
    self.escalationService = escalationService
    self.onComplete = onComplete
    self.onDelete = onDelete
    self.onUpdate = onUpdate
    self.subtasks = task.subtasks ?? []

    self.subscribeToSubtaskChanges()
  }

  /// Resolves list membership from the cached lists array.
  ///
  /// `fetchLists()` is cache-backed by ResponseCache with write-through —
  /// the lists tab already populated it, so this is an actor-isolated
  /// dictionary lookup + O(n) scan where n ≈ 10–20 lists. Zero network cost
  /// in the common case.
  ///
  /// Falls back to `fetchList(id:)` only when the list isn't in cache
  /// (deep links into a list the user hasn't browsed yet). That's a single
  /// GET, unavoidable because we genuinely don't have the data.
  func loadListInfo() async {
    do {
      let lists = try await listService.fetchLists()
      if let list = lists.first(where: { $0.id == listId }) {
        self.applyListMembers(list.members ?? [])
        return
      }
      // List not in cached array — deep link or cache miss
      let list = try await listService.fetchList(id: self.listId)
      self.applyListMembers(list.members ?? [])
    } catch {
      // Non-critical — visibility card just won't show
      Logger.debug("Could not load list info for task detail", category: .api)
    }
  }

  private func applyListMembers(_ members: [ListMemberDTO]) {
    self.listMembers = members
    self.isSharedList = members.count > 1
  }

  // MARK: - Subtask Subscription

  private func subscribeToSubtaskChanges() {
    self.subtaskManager.changePublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] change in
        guard let self, change.parentTaskId == self.task.id else { return }
        self.handleSubtaskChange(change)
      }
      .store(in: &self.cancellables)
  }

  private func handleSubtaskChange(_ change: SubtaskChange) {
    switch change.type {
    case let .completed(subtask), let .reopened(subtask), let .updated(subtask):
      if let index = subtasks.firstIndex(where: { $0.id == subtask.id }) {
        self.subtasks[index] = subtask
      }
    case let .created(subtask):
      self.subtasks.append(subtask)
    case let .deleted(subtaskId):
      self.subtasks.removeAll { $0.id == subtaskId }
    }
  }

  // MARK: - Actions

  func toggleStar() async {
    do {
      let updated = try await taskService.updateTask(
        listId: self.listId,
        taskId: self.task.id,
        title: nil,
        note: nil,
        dueAt: nil,
        color: nil,
        priority: nil,
        starred: !self.task.isStarred,
        tagIds: nil
      )
      self.task = updated
      HapticManager.success()
      await self.onUpdate()
    } catch {
      Logger.error("Failed to toggle star", error: error, category: .api)
      HapticManager.error()
      self.error = ErrorHandler.shared.handle(error, context: "Toggling star")
    }
  }

  func toggleHidden() async {
    do {
      let updated = try await taskService.updateTask(
        listId: self.listId,
        taskId: self.task.id,
        title: nil,
        note: nil,
        dueAt: nil,
        hidden: !self.task.isHidden
      )
      self.task = updated
      HapticManager.selection()
      await self.onUpdate()
    } catch {
      Logger.error("Failed to toggle hidden", error: error, category: .api)
      HapticManager.error()
      self.error = ErrorHandler.shared.handle(error, context: "Hiding task")
    }
  }

  var isNudgeOnCooldown: Bool {
    NudgeCooldownManager.shared.isOnCooldown(taskId: self.task.id)
  }

  func nudgeTask() async {
    let cooldown = NudgeCooldownManager.shared
    guard !cooldown.isOnCooldown(taskId: self.task.id) else { return }

    do {
      try await self.taskService.nudgeTask(listId: self.listId, taskId: self.task.id)
      cooldown.recordNudge(taskId: self.task.id)
      HapticManager.success()
      self.showNudgeSent = true
      self.scheduleNudgeToastDismiss()
    } catch let error as FocusmateError where error.isRateLimited {
      cooldown.recordNudge(taskId: self.task.id)
    } catch {
      Logger.error("Failed to nudge task", error: error, category: .api)
      HapticManager.error()
      self.error = ErrorHandler.shared.handle(error, context: "Sending nudge")
    }
  }

  func copyTaskLink() {
    let link = "intentia://task/\(task.id)"
    UIPasteboard.general.string = link
    HapticManager.success()
    self.showCopied = true
    self.scheduleCopiedToastDismiss()
  }

  // MARK: - Toast Dismiss Helpers

  private func scheduleNudgeToastDismiss() {
    self.nudgeToastDismissTask?.cancel()
    self.nudgeToastDismissTask = Task { [weak self] in
      do {
        try await Task.sleep(nanoseconds: Self.toastDismissDuration)
        await MainActor.run { self?.showNudgeSent = false }
      } catch {
        // Task was cancelled, don't update state
      }
    }
  }

  private func scheduleCopiedToastDismiss() {
    self.copiedToastDismissTask?.cancel()
    self.copiedToastDismissTask = Task { [weak self] in
      do {
        try await Task.sleep(nanoseconds: Self.toastDismissDuration)
        await MainActor.run { self?.showCopied = false }
      } catch {
        // Task was cancelled, don't update state
      }
    }
  }

  func rescheduleTask(newDate: Date, reason: String) async {
    do {
      let updated = try await taskService.rescheduleTask(
        listId: self.listId,
        taskId: self.task.id,
        newDueAt: newDate.ISO8601Format(),
        reason: reason
      )
      self.task = updated
      HapticManager.success()
      await self.onUpdate()
    } catch {
      Logger.error("Failed to reschedule task", error: error, category: .api)
      HapticManager.error()
      self.error = ErrorHandler.shared.handle(error, context: "Rescheduling task")
    }
  }

  func createSubtask(title: String) async {
    do {
      _ = try await self.subtaskManager.create(parentTask: self.task, title: title)
    } catch {
      Logger.error("Failed to create subtask", error: error, category: .api)
      HapticManager.error()
      self.error = ErrorHandler.shared.handle(error, context: "Creating subtask")
    }
  }

  func toggleSubtaskComplete(_ subtask: SubtaskDTO) async {
    do {
      _ = try await self.subtaskManager.toggleComplete(subtask: subtask, parentTask: self.task)
    } catch {
      Logger.error("Failed to toggle subtask", error: error, category: .api)
      HapticManager.error()
    }
  }

  func deleteSubtask(_ subtask: SubtaskDTO) async {
    do {
      try await self.subtaskManager.delete(subtask: subtask, parentTask: self.task)
    } catch {
      Logger.error("Failed to delete subtask", error: error, category: .api)
      HapticManager.error()
    }
  }

  func updateSubtask(_ subtask: SubtaskDTO, title: String) async {
    do {
      _ = try await self.subtaskManager.update(subtask: subtask, parentTask: self.task, title: title)
    } catch {
      Logger.error("Failed to update subtask", error: error, category: .api)
      HapticManager.error()
    }
  }
}
