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
    
    private var canManageMembers: Bool {
        isOwner
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
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Members button - always visible for shared lists
                Button {
                    showingMembers = true
                } label: {
                    Image(systemName: "person.2")
                }
                
                // Edit list button - only for owners
                if isOwner {
                    Button {
                        showingEditList = true
                    } label: {
                        Image(systemName: DesignSystem.Icons.edit)
                    }
                }

                // Add task button - only for editors and owners
                if canEdit {
                    Button {
                        showingCreateTask = true
                    } label: {
                        Image(systemName: DesignSystem.Icons.add)
                    }
                }
            }
        }
    }
    
    // MARK: - Sorted Task Groups
    
    private var urgentTasks: [TaskDTO] {
        tasks.filter { !$0.isCompleted && $0.taskPriority == .urgent }
            .sorted { ($0.position ?? Int.max) < ($1.position ?? Int.max) }
    }
    
    private var starredTasks: [TaskDTO] {
        tasks.filter { !$0.isCompleted && $0.taskPriority != .urgent && $0.isStarred }
            .sorted { ($0.position ?? Int.max) < ($1.position ?? Int.max) }
    }
    
    private var normalTasks: [TaskDTO] {
        tasks.filter { !$0.isCompleted && $0.taskPriority != .urgent && !$0.isStarred }
            .sorted { ($0.position ?? Int.max) < ($1.position ?? Int.max) }
    }
    
    private var completedTasks: [TaskDTO] {
        tasks.filter { $0.isCompleted }
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
                icon: DesignSystem.Icons.task,
                actionTitle: "Create Task",
                action: { showingCreateTask = true }
            )
        } else {
            EmptyStateView(
                title: "No tasks yet",
                message: "The owner hasn't added any tasks to this list",
                icon: DesignSystem.Icons.task,
                actionTitle: nil,
                action: nil
            )
        }
    }
    
    // MARK: - Task List
    
    private var taskListView: some View {
        VStack(spacing: 0) {
            // Role indicator for shared lists
            if isSharedList {
                HStack {
                    Image(systemName: roleIcon)
                        .foregroundColor(roleColor)
                    Text("You're a \(roleLabel.lowercased()) of this list")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(roleColor.opacity(0.1))
            }
            
            List {
                // Urgent section
                if !urgentTasks.isEmpty {
                    Section {
                        ForEach(urgentTasks, id: \.id) { task in
                            taskRow(for: task)
                        }
                        .onMove { source, destination in
                            if canEdit {
                                moveTask(in: .urgent, from: source, to: destination)
                            }
                        }
                    } header: {
                        Label("Urgent", systemImage: "flag.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                // Starred section
                if !starredTasks.isEmpty {
                    Section {
                        ForEach(starredTasks, id: \.id) { task in
                            taskRow(for: task)
                        }
                        .onMove { source, destination in
                            if canEdit {
                                moveTask(in: .starred, from: source, to: destination)
                            }
                        }
                    } header: {
                        Label("Starred", systemImage: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }
                
                // Normal tasks section
                if !normalTasks.isEmpty {
                    Section {
                        ForEach(normalTasks, id: \.id) { task in
                            taskRow(for: task)
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
                
                // Completed section
                if !completedTasks.isEmpty {
                    Section {
                        ForEach(completedTasks, id: \.id) { task in
                            taskRow(for: task)
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
        case "editor": return "pencil"
        case "viewer": return "eye"
        default: return "person"
        }
    }
    
    private var roleColor: Color {
        switch list.role {
        case "owner", nil: return .yellow
        case "editor": return DesignSystem.Colors.accent
        case "viewer": return .gray
        default: return .blue
        }
    }
    
    @ViewBuilder
    private func taskRow(for task: TaskDTO) -> some View {
        let taskCanEdit = task.can_edit ?? canEdit
        let taskCanDelete = task.can_delete ?? canEdit
        
        TaskRow(
            task: task,
            onComplete: { await loadTasks() },
            onStar: taskCanEdit ? { await toggleStar(task) } : nil,
            onTap: { selectedTask = task },
            onNudge: isSharedList ? { await nudgeAboutTask(task) } : nil
        )
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: taskCanDelete) {
            if taskCanDelete {
                Button("Delete", role: .destructive) {
                    HapticManager.warning()
                    Task { await deleteTask(task) }
                }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if isSharedList {
                Button {
                    Task { await nudgeAboutTask(task) }
                } label: {
                    Label("Nudge", systemImage: "hand.point.right.fill")
                }
                .tint(DesignSystem.Colors.accent)
            }
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

// MARK: - Supporting Views

struct NudgeToast: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(DesignSystem.Colors.accent)
            .cornerRadius(20)
            .shadow(radius: 4)
            .padding(.bottom, 20)
    }
}

// MARK: - Response Types

struct NudgeResponse: Codable {
    let message: String
}
