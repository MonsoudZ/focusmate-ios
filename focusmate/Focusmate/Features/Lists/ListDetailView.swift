import SwiftUI

struct ListDetailView: View {
    let list: ListDTO
    let taskService: TaskService
    let listService: ListService
    let tagService: TagService
    @Environment(\.dismiss) private var dismiss

    @State private var tasks: [TaskDTO] = []
    @State private var isLoading = false
    @State private var error: FocusmateError?
    @State private var showingCreateTask = false
    @State private var showingEditList = false
    @State private var showingDeleteConfirmation = false
    @State private var showingMembers = false
    @State private var taskNeedingReason: TaskDTO?
    @State private var taskToEdit: TaskDTO?

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Button {
                    showingMembers = true
                } label: {
                    Image(systemName: "person.2")
                }
                
                Button {
                    showingEditList = true
                } label: {
                    Image(systemName: DesignSystem.Icons.edit)
                }

                Button {
                    showingCreateTask = true
                } label: {
                    Image(systemName: DesignSystem.Icons.add)
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
                EmptyStateView(
                    title: "No tasks yet",
                    message: "Tap the + button to add your first task",
                    icon: DesignSystem.Icons.task,
                    actionTitle: "Create Task",
                    action: { showingCreateTask = true }
                )
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
        .sheet(item: $taskToEdit) { task in
            EditTaskView(listId: list.id, task: task, taskService: taskService, tagService: tagService, onSave: {
                Task { await loadTasks() }
            })
        }
        .sheet(item: $taskNeedingReason) { task in
            OverdueReasonSheet(task: task) { reason in
                Task {
                    await completeWithReason(task, reason: reason)
                    taskNeedingReason = nil
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
        .task {
            await loadTasks()
        }
        .refreshable {
            HapticManager.light()
            await loadTasks()
        }
    }
    
    private var taskListView: some View {
        List {
            // Urgent section
            if !urgentTasks.isEmpty {
                Section {
                    ForEach(urgentTasks, id: \.id) { task in
                        taskRow(for: task)
                    }
                    .onMove { source, destination in
                        moveTask(in: .urgent, from: source, to: destination)
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
                        moveTask(in: .starred, from: source, to: destination)
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
                        moveTask(in: .normal, from: source, to: destination)
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
        .environment(\.editMode, .constant(.active))
    }
    
    @ViewBuilder
    private func taskRow(for task: TaskDTO) -> some View {
        TaskRowView(
            task: task,
            onToggleComplete: {
                Task { await toggleComplete(task) }
            },
            onToggleStar: {
                Task { await toggleStar(task) }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.selection()
            taskToEdit = task
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Delete", role: .destructive) {
                HapticManager.warning()
                Task { await deleteTask(task) }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                Task { await toggleComplete(task) }
            } label: {
                Label(
                    task.isCompleted ? "Undo" : "Done",
                    systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark"
                )
            }
            .tint(task.isCompleted ? .orange : .green)
        }
    }
    
    // MARK: - Task Group Enum
    
    private enum TaskGroup {
        case urgent, starred, normal
    }
    
    private func moveTask(in group: TaskGroup, from source: IndexSet, to destination: Int) {
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
        
        // Update positions
        let updates = groupTasks.enumerated().map { (index, task) in
            (id: task.id, position: index)
        }
        
        // Optimistic update
        for (id, position) in updates {
            if let index = tasks.firstIndex(where: { $0.id == id }) {
                // We can't mutate TaskDTO directly, so we'll just sync after API call
            }
        }
        
        HapticManager.selection()
        
        // Sync to server
        Task {
            await reorderTasks(updates)
        }
    }
    
    private func reorderTasks(_ updates: [(id: Int, position: Int)]) async {
        do {
            try await taskService.reorderTasks(listId: list.id, tasks: updates)
            await loadTasks() // Refresh to get updated positions
        } catch {
            Logger.error("Failed to reorder tasks: \(error)", category: .api)
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
    
    private func toggleStar(_ task: TaskDTO) async {
        do {
            let updatedTask = try await taskService.updateTask(
                listId: task.list_id,
                taskId: task.id,
                title: nil,
                note: nil,
                dueAt: nil,
                starred: !task.isStarred
            )
            
            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[index] = updatedTask
            }
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
            return
        }
        
        if task.isOverdue {
            taskNeedingReason = task
        } else {
            do {
                _ = try await taskService.completeTask(listId: list.id, taskId: task.id)
                HapticManager.success()
                await loadTasks()
            } catch {
                self.error = ErrorHandler.shared.handle(error)
                HapticManager.error()
            }
        }
    }
    
    private func completeWithReason(_ task: TaskDTO, reason: String) async {
        do {
            _ = try await taskService.completeTask(listId: list.id, taskId: task.id, reason: reason)
            HapticManager.success()
            await loadTasks()
        } catch {
            self.error = ErrorHandler.shared.handle(error)
            HapticManager.error()
        }
    }

    private func deleteTask(_ task: TaskDTO) async {
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
