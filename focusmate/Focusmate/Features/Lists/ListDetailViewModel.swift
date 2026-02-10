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

    var tasks: [TaskDTO] = [] {
        didSet { invalidateTaskGroupsCache() }
    }
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
        // Guard ensures self is still alive before handling the change
        subtaskManager.changePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] change in
                guard let self else { return }
                self.handleSubtaskChange(change)
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
        (list.members?.count ?? 0) > 1
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
        cacheVersion += 1
    }

    private struct TaskGroups {
        var urgent: [TaskDTO]
        var starred: [TaskDTO]
        var normal: [TaskDTO]
        var completed: [TaskDTO]
    }

    private var taskGroups: TaskGroups {
        // Return cached if version hasn't changed
        if cachedVersion == cacheVersion, let cached = cachedGroups {
            return cached
        }

        // Single-pass grouping: O(n) instead of O(4n)
        var urgent: [TaskDTO] = []
        var starred: [TaskDTO] = []
        var normal: [TaskDTO] = []
        var completed: [TaskDTO] = []

        for task in tasks {
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

        cachedGroups = groups
        cachedVersion = cacheVersion
        return groups
    }

    var urgentTasks: [TaskDTO] { taskGroups.urgent }
    var starredTasks: [TaskDTO] { taskGroups.starred }
    var normalTasks: [TaskDTO] { taskGroups.normal }
    var completedTasks: [TaskDTO] { taskGroups.completed }

    // MARK: - Task Group Enum

    enum TaskGroup {
        case urgent, starred, normal
    }

    // MARK: - Actions

    func loadTasks() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

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
            HapticManager.error()
        }
    }

    func toggleHidden(_ task: TaskDTO) async {
        guard canEdit else { return }

        let originalTasks = tasks
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx].hidden = !(tasks[idx].hidden ?? false)
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
                tasks[idx] = updated
            }
            HapticManager.selection()
        } catch {
            tasks = originalTasks
            Logger.error("Failed to toggle hidden: \(error)", category: .api)
            HapticManager.error()
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
                tasks[idx].completed_at = ISO8601Utils.formatDateNoFrac(Date())
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
            tasks[idx].completed_at = ISO8601Utils.formatDateNoFrac(Date())
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
