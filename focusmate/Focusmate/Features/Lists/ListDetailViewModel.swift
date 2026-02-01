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

    init(list: ListDTO, taskService: TaskService, listService: ListService, tagService: TagService, inviteService: InviteService, friendService: FriendService) {
        self.list = list
        self.taskService = taskService
        self.listService = listService
        self.tagService = tagService
        self.inviteService = inviteService
        self.friendService = friendService
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
            self.error = ErrorHandler.shared.handle(error)
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
            self.error = ErrorHandler.shared.handle(error)
            HapticManager.error()
        }
    }

    func nudgeAboutTask(_ task: TaskDTO) async {
        do {
            let endpoint = API.Lists.taskAction(String(task.list_id), String(task.id), "nudge")
            let _: NudgeResponse = try await taskService.apiClient.request("POST", endpoint, body: nil as String?)

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
            let subtask = try await taskService.createSubtask(
                listId: parentTask.list_id,
                parentTaskId: parentTask.id,
                title: title
            )
            HapticManager.success()
            if let idx = tasks.firstIndex(where: { $0.id == parentTask.id }) {
                var existing = tasks[idx].subtasks ?? []
                existing.append(subtask)
                tasks[idx].subtasks = existing
            }
        } catch {
            Logger.error("Failed to create subtask: \(error)", category: .api)
            self.error = ErrorHandler.shared.handle(error)
            HapticManager.error()
        }
    }

    func updateSubtask(info: SubtaskEditInfo, title: String) async {
        do {
            let updated = try await taskService.updateSubtask(
                listId: info.parentTask.list_id,
                parentTaskId: info.parentTask.id,
                subtaskId: info.subtask.id,
                title: title
            )
            HapticManager.success()
            if let taskIdx = tasks.firstIndex(where: { $0.id == info.parentTask.id }),
               var subs = tasks[taskIdx].subtasks,
               let subIdx = subs.firstIndex(where: { $0.id == info.subtask.id }) {
                subs[subIdx] = updated
                tasks[taskIdx].subtasks = subs
            }
        } catch {
            Logger.error("Failed to update subtask: \(error)", category: .api)
            self.error = ErrorHandler.shared.handle(error)
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
            self.error = ErrorHandler.shared.handle(error)
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
            self.error = ErrorHandler.shared.handle(error)
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
