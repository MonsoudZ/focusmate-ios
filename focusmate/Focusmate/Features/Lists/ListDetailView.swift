import SwiftUI

struct ListDetailView: View {
    let list: ListDTO
    let taskService: TaskService
    let listService: ListService
    let tagService: TagService
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var state: AppState

    @State private var tasks: [TaskDTO] = []
    @State private var isLoading = false
    @State private var error: FocusmateError?
    @State private var showingCreateTask = false
    @State private var showingEditList = false
    @State private var showingDeleteConfirmation = false
    @State private var showingMembers = false
    @State private var selectedTask: TaskDTO?
    @State private var nudgeMessage: String?
    
    // Subtask state
    @State private var showingAddSubtask = false
    @State private var taskForSubtask: TaskDTO?
    @State private var showingEditSubtask = false
    @State private var subtaskToEdit: SubtaskDTO?
    @State private var parentTaskForSubtaskEdit: TaskDTO?
    
    // MARK: - Permission Helpers
    
    private var isOwner: Bool {
        list.role == "owner" || list.role == nil
    }
    
    private var isEditor: Bool {
        list.role == "editor"
    }
    
    private var isViewer: Bool {
        list.role == "viewer"
    }
    
    private var canEdit: Bool {
        isOwner || isEditor
    }
    
    private var isSharedList: Bool {
        list.role != nil && list.role != "owner"
    }
    
    private var roleLabel: String {
        switch list.role {
        case "owner", nil: return "Owner"
        case "editor": return "Editor"
        case "viewer": return "Viewer"
        default: return list.role ?? "Member"
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: DS.Spacing.sm) {
                Button {
                    showingMembers = true
                } label: {
                    Image(systemName: DS.Icon.share)
                }
                
                if isOwner {
                    Button {
                        showingEditList = true
                    } label: {
                        Image(systemName: DS.Icon.edit)
                    }
                }

                if canEdit {
                    Button {
                        showingCreateTask = true
                    } label: {
                        Image(systemName: DS.Icon.plus)
                    }
                }
            }
        }
    }
    
    // MARK: - Sorted Task Groups
    
    private var urgentTasks: [TaskDTO] {
        tasks.filter { !$0.isCompleted && $0.taskPriority == .urgent && !$0.isSubtask }
            .sorted { ($0.position ?? Int.max) < ($1.position ?? Int.max) }
    }
    
    private var starredTasks: [TaskDTO] {
        tasks.filter { !$0.isCompleted && $0.taskPriority != .urgent && $0.isStarred && !$0.isSubtask }
            .sorted { ($0.position ?? Int.max) < ($1.position ?? Int.max) }
    }
    
    private var normalTasks: [TaskDTO] {
        tasks.filter { !$0.isCompleted && $0.taskPriority != .urgent && !$0.isStarred && !$0.isSubtask }
            .sorted { ($0.position ?? Int.max) < ($1.position ?? Int.max) }
    }
    
    private var completedTasks: [TaskDTO] {
        tasks.filter { $0.isCompleted && !$0.isSubtask }
            .sorted { ($0.position ?? Int.max) < ($1.position ?? Int.max) }
    }

    var body: some View {
        Group {
            if isLoading && tasks.isEmpty {
                TasksLoadingView()
            } else if tasks.isEmpty {
                emptyStateView
            } else {
                taskListView
            }
        }
        .navigationTitle(list.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingCreateTask) {
            CreateTaskView(listId: list.id, taskService: taskService, tagService: tagService)
        }
        .sheet(isPresented: $showingEditList) {
            EditListView(list: list, listService: listService)
        }
        .sheet(isPresented: $showingMembers) {
            ListMembersView(list: list, apiClient: taskService.apiClient)
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailView(
                task: task,
                listName: list.name,
                onComplete: {
                    await toggleComplete(task)
                    selectedTask = nil
                },
                onDelete: {
                    await deleteTask(task)
                    selectedTask = nil
                },
                onUpdate: {
                    await loadTasks()
                },
                taskService: taskService,
                tagService: tagService,
                listId: list.id
            )
        }
        .sheet(isPresented: $showingAddSubtask) {
            if let parentTask = taskForSubtask {
                AddSubtaskSheet(parentTask: parentTask) { title in
                    await createSubtask(parentTask: parentTask, title: title)
                }
            }
        }
        .sheet(isPresented: $showingEditSubtask) {
            if let subtask = subtaskToEdit, let parentTask = parentTaskForSubtaskEdit {
                EditSubtaskSheet(subtask: subtask) { newTitle in
                    await updateSubtask(subtask: subtask, parentTask: parentTask, title: newTitle)
                }
            }
        }
        .alert("Delete List", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await deleteList() }
            }
        } message: {
            Text("Are you sure you want to delete '\(list.name)'? This action cannot be undone.")
        }
        .errorBanner($error) {
            Task { await loadTasks() }
        }
        .overlay(alignment: .bottom) {
            if let message = nudgeMessage {
                NudgeToast(message: message)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                nudgeMessage = nil
                            }
                        }
                    }
            }
        }
        .task {
            await loadTasks()
        }
        .refreshable {
            HapticManager.light()
            await loadTasks()
        }
    }
    
    // MARK: - Empty State
    
    @ViewBuilder
    private var emptyStateView: some View {
        if canEdit {
            EmptyStateView(
                title: "No tasks yet",
                message: "Tap the + button to add your first task",
                icon: DS.Icon.circle,
                actionTitle: "Create Task",
                action: { showingCreateTask = true }
            )
        } else {
            EmptyStateView(
                title: "No tasks yet",
                message: "The owner hasn't added any tasks to this list",
                icon: DS.Icon.circle,
                actionTitle: nil,
                action: nil
            )
        }
    }
    
    // MARK: - Task List
    
    private var taskListView: some View {
        VStack(spacing: 0) {
            if isSharedList {
                HStack {
                    Image(systemName: roleIcon)
                        .foregroundStyle(roleColor)
                    Text("You're a \(roleLabel.lowercased()) of this list")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, DS.Spacing.sm)
                .background(roleColor.opacity(0.1))
            }
            
            List {
                if !urgentTasks.isEmpty {
                    Section {
                        ForEach(urgentTasks, id: \.id) { task in
                            TaskRowContainer(
                                task: task,
                                canEdit: task.can_edit ?? canEdit,
                                canDelete: task.can_delete ?? canEdit,
                                isSharedList: isSharedList,
                                onComplete: { await loadTasks() },
                                onStar: { await toggleStar(task) },
                                onTap: { selectedTask = task },
                                onNudge: { await nudgeAboutTask(task) },
                                onDelete: { await deleteTask(task) },
                                onSubtaskComplete: { subtask in
                                    await toggleSubtaskComplete(subtask: subtask, parentTask: task)
                                },
                                onSubtaskDelete: { subtask in
                                    await deleteSubtask(subtask: subtask, parentTask: task)
                                },
                                onSubtaskEdit: { subtask in
                                    subtaskToEdit = subtask
                                    parentTaskForSubtaskEdit = task
                                    showingEditSubtask = true
                                },
                                onAddSubtask: {
                                    taskForSubtask = task
                                    showingAddSubtask = true
                                }
                            )
                        }
                        .onMove { source, destination in
                            if canEdit {
                                moveTask(in: .urgent, from: source, to: destination)
                            }
                        }
                    } header: {
                        Label("Urgent", systemImage: "flag.fill")
                            .foregroundStyle(DS.Colors.error)
                            .font(.caption)
                    }
                }
                
                if !starredTasks.isEmpty {
                    Section {
                        ForEach(starredTasks, id: \.id) { task in
                            TaskRowContainer(
                                task: task,
                                canEdit: task.can_edit ?? canEdit,
                                canDelete: task.can_delete ?? canEdit,
                                isSharedList: isSharedList,
                                onComplete: { await loadTasks() },
                                onStar: { await toggleStar(task) },
                                onTap: { selectedTask = task },
                                onNudge: { await nudgeAboutTask(task) },
                                onDelete: { await deleteTask(task) },
                                onSubtaskComplete: { subtask in
                                    await toggleSubtaskComplete(subtask: subtask, parentTask: task)
                                },
                                onSubtaskDelete: { subtask in
                                    await deleteSubtask(subtask: subtask, parentTask: task)
                                },
                                onSubtaskEdit: { subtask in
                                    subtaskToEdit = subtask
                                    parentTaskForSubtaskEdit = task
                                    showingEditSubtask = true
                                },
                                onAddSubtask: {
                                    taskForSubtask = task
                                    showingAddSubtask = true
                                }
                            )
                        }
                        .onMove { source, destination in
                            if canEdit {
                                moveTask(in: .starred, from: source, to: destination)
                            }
                        }
                    } header: {
                        Label("Starred", systemImage: DS.Icon.starFilled)
                            .foregroundStyle(.yellow)
                            .font(.caption)
                    }
                }
                
                if !normalTasks.isEmpty {
                    Section {
                        ForEach(normalTasks, id: \.id) { task in
                            TaskRowContainer(
                                task: task,
                                canEdit: task.can_edit ?? canEdit,
                                canDelete: task.can_delete ?? canEdit,
                                isSharedList: isSharedList,
                                onComplete: { await loadTasks() },
                                onStar: { await toggleStar(task) },
                                onTap: { selectedTask = task },
                                onNudge: { await nudgeAboutTask(task) },
                                onDelete: { await deleteTask(task) },
                                onSubtaskComplete: { subtask in
                                    await toggleSubtaskComplete(subtask: subtask, parentTask: task)
                                },
                                onSubtaskDelete: { subtask in
                                    await deleteSubtask(subtask: subtask, parentTask: task)
                                },
                                onSubtaskEdit: { subtask in
                                    subtaskToEdit = subtask
                                    parentTaskForSubtaskEdit = task
                                    showingEditSubtask = true
                                },
                                onAddSubtask: {
                                    taskForSubtask = task
                                    showingAddSubtask = true
                                }
                            )
                        }
                        .onMove { source, destination in
                            if canEdit {
                                moveTask(in: .normal, from: source, to: destination)
                            }
                        }
                    } header: {
                        Text("Tasks")
                            .font(.caption)
                    }
                }
                
                if !completedTasks.isEmpty {
                    Section {
                        ForEach(completedTasks, id: \.id) { task in
                            TaskRowContainer(
                                task: task,
                                canEdit: task.can_edit ?? canEdit,
                                canDelete: task.can_delete ?? canEdit,
                                isSharedList: isSharedList,
                                onComplete: { await loadTasks() },
                                onStar: { await toggleStar(task) },
                                onTap: { selectedTask = task },
                                onNudge: { await nudgeAboutTask(task) },
                                onDelete: { await deleteTask(task) },
                                onSubtaskComplete: { subtask in
                                    await toggleSubtaskComplete(subtask: subtask, parentTask: task)
                                },
                                onSubtaskDelete: { subtask in
                                    await deleteSubtask(subtask: subtask, parentTask: task)
                                },
                                onSubtaskEdit: { subtask in
                                    subtaskToEdit = subtask
                                    parentTaskForSubtaskEdit = task
                                    showingEditSubtask = true
                                },
                                onAddSubtask: {
                                    taskForSubtask = task
                                    showingAddSubtask = true
                                }
                            )
                        }
                    } header: {
                        Text("Completed")
                            .font(.caption)
                    }
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, canEdit ? .constant(.active) : .constant(.inactive))
        }
    }
    
    private var roleIcon: String {
        switch list.role {
        case "owner", nil: return "crown.fill"
        case "editor": return DS.Icon.edit
        case "viewer": return "eye"
        default: return "person"
        }
    }
    
    private var roleColor: Color {
        switch list.role {
        case "owner", nil: return .yellow
        case "editor": return DS.Colors.accent
        case "viewer": return Color(.secondaryLabel)
        default: return DS.Colors.accent
        }
    }
    
    // MARK: - Task Group Enum
    
    private enum TaskGroup {
        case urgent, starred, normal
    }
    
    private func moveTask(in group: TaskGroup, from source: IndexSet, to destination: Int) {
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
    
    private func reorderTasks(_ updates: [(id: Int, position: Int)]) async {
        do {
            try await taskService.reorderTasks(listId: list.id, tasks: updates)
            await loadTasks()
        } catch {
            Logger.error("Failed to reorder tasks: \(error)", category: .api)
            self.error = ErrorHandler.shared.handle(error)
            HapticManager.error()
        }
    }
    
    // MARK: - Task Actions
    
    private func toggleStar(_ task: TaskDTO) async {
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
    
    private func toggleComplete(_ task: TaskDTO) async {
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

    private func deleteTask(_ task: TaskDTO) async {
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
    
    private func nudgeAboutTask(_ task: TaskDTO) async {
        do {
            let endpoint = API.Lists.taskAction(String(task.list_id), String(task.id), "nudge")
            let _: NudgeResponse = try await state.auth.api.request("POST", endpoint, body: nil as String?)
            
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
    
    private func createSubtask(parentTask: TaskDTO, title: String) async {
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
    
    private func toggleSubtaskComplete(subtask: SubtaskDTO, parentTask: TaskDTO) async {
        do {
            if subtask.isCompleted {
                _ = try await taskService.reopenSubtask(listId: parentTask.list_id, subtaskId: subtask.id)
            } else {
                _ = try await taskService.completeSubtask(listId: parentTask.list_id, subtaskId: subtask.id)
            }
            HapticManager.light()
            await loadTasks()
        } catch {
            Logger.error("Failed to toggle subtask: \(error)", category: .api)
            self.error = ErrorHandler.shared.handle(error)
            HapticManager.error()
        }
    }
    
    private func deleteSubtask(subtask: SubtaskDTO, parentTask: TaskDTO) async {
        do {
            try await taskService.deleteSubtask(listId: parentTask.list_id, subtaskId: subtask.id)
            HapticManager.medium()
            await loadTasks()
        } catch {
            Logger.error("Failed to delete subtask: \(error)", category: .api)
            self.error = ErrorHandler.shared.handle(error)
            HapticManager.error()
        }
    }
    
    private func updateSubtask(subtask: SubtaskDTO, parentTask: TaskDTO, title: String) async {
        do {
            _ = try await taskService.updateTask(
                listId: parentTask.list_id,
                taskId: subtask.id,
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
    
    private func loadTasks() async {
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

    private func deleteList() async {
        do {
            try await listService.deleteList(id: list.id)
            HapticManager.medium()
            dismiss()
        } catch {
            self.error = ErrorHandler.shared.handle(error)
            HapticManager.error()
        }
    }
}

// MARK: - Task Row Container

struct TaskRowContainer: View {
    let task: TaskDTO
    let canEdit: Bool
    let canDelete: Bool
    let isSharedList: Bool
    let onComplete: () async -> Void
    let onStar: () async -> Void
    let onTap: () -> Void
    let onNudge: () async -> Void
    let onDelete: () async -> Void
    let onSubtaskComplete: (SubtaskDTO) async -> Void
    let onSubtaskDelete: (SubtaskDTO) async -> Void
    let onSubtaskEdit: (SubtaskDTO) -> Void
    let onAddSubtask: () -> Void
    
    var body: some View {
        TaskRow(
            task: task,
            onComplete: onComplete,
            onStar: onStar,
            onTap: onTap,
            onNudge: onNudge,
            onSubtaskComplete: onSubtaskComplete,
            onSubtaskDelete: onSubtaskDelete,
            onSubtaskEdit: onSubtaskEdit,
            onAddSubtask: onAddSubtask,
            showStar: canEdit,
            showNudge: isSharedList
        )
        .listRowInsets(EdgeInsets(top: DS.Spacing.xs, leading: DS.Spacing.lg, bottom: DS.Spacing.xs, trailing: DS.Spacing.lg))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: canDelete) {
            if canDelete {
                Button("Delete", role: .destructive) {
                    HapticManager.warning()
                    Task { await onDelete() }
                }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if isSharedList {
                Button {
                    Task { await onNudge() }
                } label: {
                    Label("Nudge", systemImage: "hand.point.right.fill")
                }
                .tint(DS.Colors.accent)
            }
        }
    }
}

// MARK: - Supporting Views

struct NudgeToast: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Colors.accent)
            .cornerRadius(DS.Radius.lg)
            .shadow(radius: 4)
            .padding(.bottom, DS.Spacing.xl)
    }
}

// MARK: - Response Types

struct NudgeResponse: Codable {
    let message: String
}
