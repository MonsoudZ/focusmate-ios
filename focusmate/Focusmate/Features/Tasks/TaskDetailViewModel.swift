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
    private let escalationService: EscalationService

    private var cancellables = Set<AnyCancellable>()
    private var nudgeToastDismissTask: Task<Void, Never>?
    private var copiedToastDismissTask: Task<Void, Never>?

    /// Duration for auto-dismissing toast messages (2 seconds)
    private static let toastDismissDuration: UInt64 = 2_000_000_000

    // MARK: - Computed Properties

    var isOverdue: Bool {
        task.isActuallyOverdue
    }

    var isTrackedForEscalation: Bool {
        escalationService.isTaskTracked(task.id)
    }

    /// Whether completing this task requires a reason (overdue or tracked for escalation)
    var requiresCompletionReason: Bool {
        isOverdue || isTrackedForEscalation
    }

    var canEdit: Bool {
        task.can_edit ?? true
    }

    var isSharedTask: Bool {
        task.creator != nil
    }

    var canHide: Bool {
        isSharedTask && canEdit
    }

    var subtaskProgress: Double {
        guard !subtasks.isEmpty else { return 0 }
        let completed = subtasks.filter { $0.isCompleted }.count
        return Double(completed) / Double(subtasks.count)
    }

    var subtaskProgressText: String {
        let completed = subtasks.filter { $0.isCompleted }.count
        return "\(completed)/\(subtasks.count)"
    }

    var hasSubtasks: Bool {
        !subtasks.isEmpty
    }

    var hasRescheduleHistory: Bool {
        task.hasBeenRescheduled
    }

    var rescheduleCount: Int {
        task.rescheduleCount
    }

    var rescheduleEvents: [RescheduleEventDTO] {
        task.reschedule_events ?? []
    }

    // MARK: - Init

    init(
        task: TaskDTO,
        listName: String,
        listId: Int,
        taskService: TaskService,
        tagService: TagService,
        subtaskManager: SubtaskManager,
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
        self.escalationService = escalationService
        self.onComplete = onComplete
        self.onDelete = onDelete
        self.onUpdate = onUpdate
        self.subtasks = task.subtasks ?? []

        subscribeToSubtaskChanges()
    }

    // MARK: - Subtask Subscription

    private func subscribeToSubtaskChanges() {
        subtaskManager.changePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                guard let self, change.parentTaskId == self.task.id else { return }
                self.handleSubtaskChange(change)
            }
            .store(in: &cancellables)
    }

    private func handleSubtaskChange(_ change: SubtaskChange) {
        switch change.type {
        case .completed(let subtask), .reopened(let subtask), .updated(let subtask):
            if let index = subtasks.firstIndex(where: { $0.id == subtask.id }) {
                subtasks[index] = subtask
            }
        case .created(let subtask):
            subtasks.append(subtask)
        case .deleted(let subtaskId):
            subtasks.removeAll { $0.id == subtaskId }
        }
    }

    // MARK: - Actions

    func toggleStar() async {
        do {
            let updated = try await taskService.updateTask(
                listId: listId,
                taskId: task.id,
                title: nil,
                note: nil,
                dueAt: nil,
                color: nil,
                priority: nil,
                starred: !task.isStarred,
                tagIds: nil
            )
            task = updated
            HapticManager.success()
            await onUpdate()
        } catch {
            Logger.error("Failed to toggle star", error: error, category: .api)
            HapticManager.error()
            self.error = ErrorHandler.shared.handle(error, context: "Toggling star")
        }
    }

    func toggleHidden() async {
        do {
            let updated = try await taskService.updateTask(
                listId: listId,
                taskId: task.id,
                title: nil,
                note: nil,
                dueAt: nil,
                hidden: !task.isHidden
            )
            task = updated
            HapticManager.selection()
            await onUpdate()
        } catch {
            Logger.error("Failed to toggle hidden", error: error, category: .api)
            HapticManager.error()
            self.error = ErrorHandler.shared.handle(error, context: "Hiding task")
        }
    }

    func nudgeTask() async {
        do {
            try await taskService.nudgeTask(listId: listId, taskId: task.id)
            HapticManager.success()
            showNudgeSent = true
            scheduleNudgeToastDismiss()
        } catch {
            Logger.error("Failed to nudge task", error: error, category: .api)
            HapticManager.error()
            self.error = ErrorHandler.shared.handle(error, context: "Sending nudge")
        }
    }

    func copyTaskLink() {
        let link = "focusmate://task/\(task.id)"
        UIPasteboard.general.string = link
        HapticManager.success()
        showCopied = true
        scheduleCopiedToastDismiss()
    }

    // MARK: - Toast Dismiss Helpers

    private func scheduleNudgeToastDismiss() {
        nudgeToastDismissTask?.cancel()
        nudgeToastDismissTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: Self.toastDismissDuration)
                showNudgeSent = false
            } catch {
                // Task was cancelled, don't update state
            }
        }
    }

    private func scheduleCopiedToastDismiss() {
        copiedToastDismissTask?.cancel()
        copiedToastDismissTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: Self.toastDismissDuration)
                showCopied = false
            } catch {
                // Task was cancelled, don't update state
            }
        }
    }

    func rescheduleTask(newDate: Date, reason: String) async {
        do {
            let updated = try await taskService.rescheduleTask(
                listId: listId,
                taskId: task.id,
                newDueAt: newDate.ISO8601Format(),
                reason: reason
            )
            task = updated
            HapticManager.success()
            await onUpdate()
        } catch {
            Logger.error("Failed to reschedule task", error: error, category: .api)
            HapticManager.error()
            self.error = ErrorHandler.shared.handle(error, context: "Rescheduling task")
        }
    }

    func createSubtask(title: String) async {
        do {
            _ = try await subtaskManager.create(parentTask: task, title: title)
        } catch {
            Logger.error("Failed to create subtask", error: error, category: .api)
            HapticManager.error()
            self.error = ErrorHandler.shared.handle(error, context: "Creating subtask")
        }
    }

    func toggleSubtaskComplete(_ subtask: SubtaskDTO) async {
        do {
            _ = try await subtaskManager.toggleComplete(subtask: subtask, parentTask: task)
        } catch {
            Logger.error("Failed to toggle subtask", error: error, category: .api)
            HapticManager.error()
        }
    }

    func deleteSubtask(_ subtask: SubtaskDTO) async {
        do {
            try await subtaskManager.delete(subtask: subtask, parentTask: task)
        } catch {
            Logger.error("Failed to delete subtask", error: error, category: .api)
            HapticManager.error()
        }
    }

    func updateSubtask(_ subtask: SubtaskDTO, title: String) async {
        do {
            _ = try await subtaskManager.update(subtask: subtask, parentTask: task, title: title)
        } catch {
            Logger.error("Failed to update subtask", error: error, category: .api)
            HapticManager.error()
        }
    }
}
