import Combine
import Foundation
import SwiftUI

@MainActor
final class ListDetailViewModel: ObservableObject {
    let list: ListDTO
    let taskService: TaskService
    let listService: ListService
    let tagService: TagService

    // MARK: - Data

    @Published var tasks: [TaskDTO] = []
    @Published var isLoading = false
    @Published var error: FocusmateError?

    // MARK: - Sheets

    @Published var showingCreateTask = false
    @Published var showingEditList = false
    @Published var showingDeleteConfirmation = false
    @Published var showingMembers = false
    @Published var selectedTask: TaskDTO?

    // MARK: - Subtask

    @Published var showingAddSubtask = false
    @Published var taskForSubtask: TaskDTO?
    @Published var showingEditSubtask = false
    @Published var subtaskToEdit: SubtaskDTO?
    @Published var parentTaskForSubtaskEdit: TaskDTO?

    // MARK: - UI

    @Published var nudgeMessage: String?

    // MARK: - Callback

    var onDismiss: (() -> Void)?

    // MARK: - Init

    init(list: ListDTO, taskService: TaskService, listService: ListService, tagService: TagService) {
        self.list = list
        self.taskService = taskService
        self.listService = listService
        self.tagService = tagService
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

        do {
            _ = try await taskService.updateTask(
                listId: task.list_id,
                taskId: task.id,
                title: nil,
                note: nil,
                dueAt: nil,
                starred: !task.isStarred
            )
            await loadTasks()
        } catch {
            Logger.error("Failed to toggle star: \(error)", category: .api)
        }
    }

    func toggleComplete(_ task: TaskDTO) async {
        if task.isCompleted {
            do {
                _ = try await taskService.reopenTask(listId: list.id, taskId: task.id)
                HapticManager.light()
                await loadTasks()
            } catch {
                self.error = ErrorHandler.shared.handle(error)
                HapticManager.error()
            }
        } else {
            await loadTasks()
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
            _ = try await taskService.createSubtask(
                listId: parentTask.list_id,
                parentTaskId: parentTask.id,
                title: title
            )
            HapticManager.success()
            await loadTasks()
        } catch {
            Logger.error("Failed to create subtask: \(error)", category: .api)
            self.error = ErrorHandler.shared.handle(error)
            HapticManager.error()
        }
    }

    func toggleSubtaskComplete(subtask: SubtaskDTO, parentTask: TaskDTO) async {
        do {
            if subtask.isCompleted {
                _ = try await taskService.reopenSubtask(listId: parentTask.list_id, subtaskId: subtask.apiId)
            } else {
                _ = try await taskService.completeSubtask(listId: parentTask.list_id, subtaskId: subtask.apiId)
            }
            HapticManager.light()
            await loadTasks()
        } catch {
            Logger.error("Failed to toggle subtask: \(error)", category: .api)
            self.error = ErrorHandler.shared.handle(error)
            HapticManager.error()
        }
    }

    func deleteSubtask(subtask: SubtaskDTO, parentTask: TaskDTO) async {
        do {
            try await taskService.deleteSubtask(listId: parentTask.list_id, subtaskId: subtask.apiId)
            HapticManager.medium()
            await loadTasks()
        } catch {
            Logger.error("Failed to delete subtask: \(error)", category: .api)
            self.error = ErrorHandler.shared.handle(error)
            HapticManager.error()
        }
    }

    func updateSubtask(subtask: SubtaskDTO, parentTask: TaskDTO, title: String) async {
        do {
            _ = try await taskService.updateTask(
                listId: parentTask.list_id,
                taskId: subtask.apiId,
                title: title,
                note: nil,
                dueAt: nil
            )
            HapticManager.success()
            await loadTasks()
        } catch {
            Logger.error("Failed to update subtask: \(error)", category: .api)
            self.error = ErrorHandler.shared.handle(error)
            HapticManager.error()
        }
    }

    func reorderTasks(_ updates: [(id: Int, position: Int)]) async {
        do {
            try await taskService.reorderTasks(listId: list.id, tasks: updates)
            await loadTasks()
        } catch {
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

        HapticManager.selection()

        Task {
            await reorderTasks(updates)
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

    // MARK: - Sheet Helpers

    func startAddSubtask(for task: TaskDTO) {
        taskForSubtask = task
        showingAddSubtask = true
    }

    func startEditSubtask(_ subtask: SubtaskDTO, parentTask: TaskDTO) {
        subtaskToEdit = subtask
        parentTaskForSubtaskEdit = parentTask
        showingEditSubtask = true
    }
}
