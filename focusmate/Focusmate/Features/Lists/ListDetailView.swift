import SwiftUI

struct ListDetailView: View {
    let list: ListDTO
    let taskService: TaskService
    let listService: ListService
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
            CreateTaskView(listId: list.id, taskService: taskService)
        }
        .sheet(isPresented: $showingEditList) {
            EditListView(list: list, listService: listService)
        }
        .sheet(isPresented: $showingMembers) {
            ListMembersView(list: list, apiClient: taskService.apiClient)
        }
        .sheet(item: $taskToEdit) { task in
            EditTaskView(listId: list.id, task: task, taskService: taskService, onSave: {
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
            await loadTasks()
        }
    }
    
    private var taskListView: some View {
        List {
            ForEach(tasks, id: \.id) { task in
                TaskRowView(
                    task: task,
                    onToggleComplete: {
                        Task { await toggleComplete(task) }
                    }
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    taskToEdit = task
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("Delete", role: .destructive) {
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
        }
        .listStyle(.plain)
    }

    private func loadTasks() async {
        isLoading = true
        error = nil

        do {
            let response = try await taskService.fetchTasks(listId: list.id)
            tasks = response
        } catch let err as FocusmateError {
            error = err
        } catch {
            self.error = ErrorHandler.shared.handle(error)
        }

        isLoading = false
    }

    private func toggleComplete(_ task: TaskDTO) async {
        if task.isCompleted {
            do {
                _ = try await taskService.reopenTask(listId: list.id, taskId: task.id)
                await loadTasks()
            } catch {
                self.error = ErrorHandler.shared.handle(error)
            }
            return
        }
        
        if task.isOverdue {
            taskNeedingReason = task
        } else {
            do {
                _ = try await taskService.completeTask(listId: list.id, taskId: task.id)
                await loadTasks()
            } catch {
                self.error = ErrorHandler.shared.handle(error)
            }
        }
    }
    
    private func completeWithReason(_ task: TaskDTO, reason: String) async {
        do {
            _ = try await taskService.completeTask(listId: list.id, taskId: task.id, reason: reason)
            await loadTasks()
        } catch {
            self.error = ErrorHandler.shared.handle(error)
        }
    }

    private func deleteTask(_ task: TaskDTO) async {
        let originalTasks = tasks
        tasks.removeAll { $0.id == task.id }

        do {
            try await taskService.deleteTask(listId: list.id, taskId: task.id)
        } catch {
            tasks = originalTasks
            self.error = ErrorHandler.shared.handle(error)
        }
    }

    private func deleteList() async {
        do {
            try await listService.deleteList(id: list.id)
            dismiss()
        } catch {
            self.error = ErrorHandler.shared.handle(error)
        }
    }
}
