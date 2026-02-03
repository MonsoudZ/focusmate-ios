import Combine
import Foundation
import SwiftUI

@MainActor
@Observable
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

    var tasks: [TaskDTO] = []
    var isLoading = false
    var error: FocusmateError?

    // MARK: - Alerts

    var showingDeleteConfirmation = false

    // MARK: - UI

    var nudgeMessage: String?

    // MARK: - Callback

    var onDismiss: (() -> Void)?

    // MARK: - Init

    init(list: ListDTO, taskService: TaskService, listService: ListService, tagService: TagService, inviteService: InviteService, friendService: FriendService, subtaskManager: SubtaskManager) {
        self.list = list
        self.taskService = taskService
        self.listService = listService
        self.tagService = tagService
        self.inviteService = inviteService
        self.friendService = friendService
        self.subtaskManager = subtaskManager

        // Subscribe to subtask changes and update local state
        subtaskManager.changePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] change in
                self?.handleSubtaskChange(change)
            }
            .store(in: &cancellables)
    }

    // MARK: - Subtask Change Handling

    private func handleSubtaskChange(_ change: SubtaskChange) {
        // Only handle changes for tasks in this list
        guard change.listId == list.id else { return }
        guard let taskIdx = tasks.firstIndex(where: { $0.id == change.parentTaskId }) else { return }

        switch change.type {
        case .completed(let subtask), .reopened(let subtask), .updated(let subtask):
            if var subs = tasks[taskIdx].subtasks,
               let subIdx = subs.firstIndex(where: { $0.id == subtask.id }) {
                subs[subIdx] = subtask
                tasks[taskIdx].subtasks = subs
            }
        case .created(let subtask):
            var existing = tasks[taskIdx].subtasks ?? []
            existing.append(subtask)
            tasks[taskIdx].subtasks = existing
        case .deleted(let subtaskId):
            if var subs = tasks[taskIdx].subtasks {
                subs.removeAll { $0.id == subtaskId }
                tasks[taskIdx].subtasks = subs
            }
        }
    }

    // MARK: - Computed: Permissions

    var isOwner: Bool {
        list.role == "owner" || list.role == nil
    }

    var isEditor: Bool {
        list.role == "editor"
    }

    var isViewer: Bool {
        list.role == "viewer"
    }

    var canEdit: Bool {
        isOwner || isEditor
    }

    var isSharedList: Bool {
        list.role != nil && list.role != "owner"
    }

    var roleLabel: String {
        switch list.role {
        case "owner", nil: return "Owner"
        case "editor": return "Editor"
        case "viewer": return "Viewer"
        default: return list.role ?? "Member"
        }
    }

    var roleIcon: String {
        switch list.role {
        case "owner", nil: return "crown.fill"
        case "editor": return DS.Icon.edit
        case "viewer": return "eye"
        default: return "person"
        }
    }

    var roleColor: Color {
        switch list.role {
        case "owner", nil: return .yellow
        case "editor": return DS.Colors.accent
        case "viewer": return Color(.secondaryLabel)
        default: return DS.Colors.accent
        }
    }

    // MARK: - Computed: Task Groups

    var urgentTasks: [TaskDTO] {
        tasks.filter { !$0.isCompleted && $0.taskPriority == .urgent && !$0.isSubtask }
            .sorted { ($0.position ?? Int.max) < ($1.position ?? Int.max) }
    }

    var starredTasks: [TaskDTO] {
        tasks.filter { !$0.isCompleted && $0.taskPriority != .urgent && $0.isStarred && !$0.isSubtask }
            .sorted { ($0.position ?? Int.max) < ($1.position ?? Int.max) }
    }

    var normalTasks: [TaskDTO] {
        tasks.filter { !$0.isCompleted && $0.taskPriority != .urgent && !$0.isStarred && !$0.isSubtask }
            .sorted { ($0.position ?? Int.max) < ($1.position ?? Int.max) }
    }

    var completedTasks: [TaskDTO] {
        tasks.filter { $0.isCompleted && !$0.isSubtask }
            .sorted { ($0.position ?? Int.max) < ($1.position ?? Int.max) }
    }

    // MARK: - Task Group Enum

    enum TaskGroup {
        case urgent, starred, normal
    }

    // MARK: - Actions

    func loadTasks() async {
        isLoading = true
        error = nil

        do {
            let response = try await taskService.fetchTasks(listId: list.id)
            tasks = response
        } catch let err as FocusmateError {
            error = err
            HapticManager.error()
        } catch {
            self.error = ErrorHandler.shared.handle(error, context: "Loading tasks")
            HapticManager.error()
        }

        isLoading = false
    }

    func toggleStar(_ task: TaskDTO) async {
        guard canEdit else { return }

        let originalTasks = tasks
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx].starred = !(tasks[idx].starred ?? false)
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
                tasks[idx] = updated
            }
        } catch {
            tasks = originalTasks
            Logger.error("Failed to toggle star: \(error)", category: .api)
        }
    }

    func toggleComplete(_ task: TaskDTO, reason: String? = nil) async {
        if task.isCompleted {
            let originalTasks = tasks
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[idx].completed_at = nil
            }

            do {
                let updated = try await taskService.reopenTask(listId: list.id, taskId: task.id)
                HapticManager.light()
                if let idx = tasks.firstIndex(where: { $0.id == updated.id }) {
                    tasks[idx] = updated
                }
            } catch {
                tasks = originalTasks
                self.error = ErrorHandler.shared.handle(error, context: "Reopening task")
                HapticManager.error()
            }
        } else {
            // Optimistic UI update
            let originalTasks = tasks
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[idx].completed_at = ISO8601DateFormatter().string(from: Date())
            }

            do {
                let updated = try await taskService.completeTask(listId: list.id, taskId: task.id, reason: reason)
                HapticManager.success()
                if let idx = tasks.firstIndex(where: { $0.id == updated.id }) {
                    tasks[idx] = updated
                }
            } catch {
                tasks = originalTasks
                self.error = ErrorHandler.shared.handle(error, context: "Completing task")
                HapticManager.error()
            }
        }
    }

    /// Updates local task state to show as completed.
    /// Called by TaskRow's onComplete callback after TaskRow handles the API call.
    func markTaskCompleted(_ taskId: Int) {
        if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
            tasks[idx].completed_at = ISO8601DateFormatter().string(from: Date())
        }
    }

    func deleteTask(_ task: TaskDTO) async {
        guard task.can_delete ?? canEdit else { return }

        let originalTasks = tasks
        tasks.removeAll { $0.id == task.id }
        HapticManager.medium()

        do {
            try await taskService.deleteTask(listId: list.id, taskId: task.id)
        } catch {
            tasks = originalTasks
            self.error = ErrorHandler.shared.handle(error, context: "Deleting task")
            HapticManager.error()
        }
    }

    func nudgeAboutTask(_ task: TaskDTO) async {
        do {
            try await taskService.nudgeTask(listId: task.list_id, taskId: task.id)
            HapticManager.success()
            withAnimation {
                nudgeMessage = "Nudge sent!"
            }
        } catch {
            Logger.error("Failed to nudge: \(error)", category: .api)
            HapticManager.error()
            withAnimation {
                nudgeMessage = "Couldn't send nudge"
            }
        }
    }

    // MARK: - Subtask Actions

    func createSubtask(parentTask: TaskDTO, title: String) async {
        do {
            _ = try await subtaskManager.create(parentTask: parentTask, title: title)
            // Local state is updated via changePublisher subscription
        } catch {
            Logger.error("Failed to create subtask: \(error)", category: .api)
            self.error = ErrorHandler.shared.handle(error, context: "Creating subtask")
            HapticManager.error()
        }
    }

    func updateSubtask(info: SubtaskEditInfo, title: String) async {
        do {
            _ = try await subtaskManager.update(subtask: info.subtask, parentTask: info.parentTask, title: title)
            // Local state is updated via changePublisher subscription
        } catch {
            Logger.error("Failed to update subtask: \(error)", category: .api)
            self.error = ErrorHandler.shared.handle(error, context: "Updating subtask")
            HapticManager.error()
        }
    }

    func reorderTasks(_ updates: [(id: Int, position: Int)], originalTasks: [TaskDTO]? = nil) async {
        do {
            try await taskService.reorderTasks(listId: list.id, tasks: updates)
        } catch {
            if let originalTasks {
                tasks = originalTasks
            }
            Logger.error("Failed to reorder tasks: \(error)", category: .api)
            self.error = ErrorHandler.shared.handle(error, context: "Reordering tasks")
            HapticManager.error()
        }
    }

    func moveTask(in group: TaskGroup, from source: IndexSet, to destination: Int) {
        guard canEdit else { return }

        var groupTasks: [TaskDTO]

        switch group {
        case .urgent:
            groupTasks = urgentTasks
        case .starred:
            groupTasks = starredTasks
        case .normal:
            groupTasks = normalTasks
        }

        groupTasks.move(fromOffsets: source, toOffset: destination)

        let updates = groupTasks.enumerated().map { (index, task) in
            (id: task.id, position: index)
        }

        let originalTasks = tasks

        for (id, position) in updates {
            if let idx = tasks.firstIndex(where: { $0.id == id }) {
                tasks[idx].position = position
            }
        }

        HapticManager.selection()

        Task {
            await reorderTasks(updates, originalTasks: originalTasks)
        }
    }

    func deleteList() async {
        do {
            try await listService.deleteList(id: list.id)
            HapticManager.medium()
            onDismiss?()
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
