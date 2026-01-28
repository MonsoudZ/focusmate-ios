import SwiftUI

struct ListDetailView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel: ListDetailViewModel

    init(list: ListDTO, taskService: TaskService, listService: ListService, tagService: TagService) {
        _viewModel = StateObject(wrappedValue: ListDetailViewModel(
            list: list,
            taskService: taskService,
            listService: listService,
            tagService: tagService
        ))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.tasks.isEmpty {
                TasksLoadingView()
            } else if viewModel.tasks.isEmpty {
                emptyStateView
            } else {
                taskListView
            }
        }
        .navigationTitle(viewModel.list.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $viewModel.showingCreateTask) {
            CreateTaskView(listId: viewModel.list.id, taskService: viewModel.taskService, tagService: viewModel.tagService)
        }
        .sheet(isPresented: $viewModel.showingEditList) {
            EditListView(list: viewModel.list, listService: viewModel.listService)
        }
        .sheet(isPresented: $viewModel.showingMembers) {
            ListMembersView(list: viewModel.list, apiClient: viewModel.taskService.apiClient)
        }
        .sheet(item: $viewModel.selectedTask) { task in
            TaskDetailView(
                task: task,
                listName: viewModel.list.name,
                onComplete: {
                    await viewModel.toggleComplete(task)
                    viewModel.selectedTask = nil
                },
                onDelete: {
                    await viewModel.deleteTask(task)
                    viewModel.selectedTask = nil
                },
                onUpdate: {
                    await viewModel.loadTasks()
                },
                taskService: viewModel.taskService,
                tagService: viewModel.tagService,
                listId: viewModel.list.id
            )
        }
        .sheet(item: $viewModel.taskForSubtask) { parentTask in
            AddSubtaskSheet(parentTask: parentTask) { title in
                await viewModel.createSubtask(parentTask: parentTask, title: title)
            }
        }
        .sheet(item: $viewModel.subtaskEditInfo) { info in
            EditSubtaskSheet(subtask: info.subtask) { newTitle in
                await viewModel.updateSubtask(info: info, title: newTitle)
            }
        }
        .alert("Delete List", isPresented: $viewModel.showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteList() }
            }
        } message: {
            Text("Are you sure you want to delete '\(viewModel.list.name)'? This action cannot be undone.")
        }
        .errorBanner($viewModel.error) {
            Task { await viewModel.loadTasks() }
        }
        .overlay(alignment: .bottom) {
            if let message = viewModel.nudgeMessage {
                NudgeToast(message: message)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                viewModel.nudgeMessage = nil
                            }
                        }
                    }
            }
        }
        .task {
            await viewModel.loadTasks()
        }
        .refreshable {
            HapticManager.light()
            await viewModel.loadTasks()
        }
        .onAppear {
            viewModel.onDismiss = { dismiss() }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: DS.Spacing.sm) {
                if viewModel.canEdit {
                    Button {
                        viewModel.showingCreateTask = true
                    } label: {
                        Image(systemName: DS.Icon.plus)
                    }
                }

                Menu {
                    Button {
                        viewModel.showingMembers = true
                    } label: {
                        Label("Members", systemImage: DS.Icon.share)
                    }

                    if viewModel.isOwner {
                        Button {
                            viewModel.showingEditList = true
                        } label: {
                            Label("Edit List", systemImage: DS.Icon.edit)
                        }
                    }

                    if viewModel.isOwner {
                        Divider()

                        Button(role: .destructive) {
                            viewModel.showingDeleteConfirmation = true
                        } label: {
                            Label("Delete List", systemImage: DS.Icon.trash)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        if viewModel.canEdit {
            EmptyStateView(
                title: "No tasks yet",
                message: "Tap the + button to add your first task",
                icon: DS.Icon.circle,
                actionTitle: "Create Task",
                action: { viewModel.showingCreateTask = true }
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
            if viewModel.isSharedList {
                HStack {
                    Image(systemName: viewModel.roleIcon)
                        .foregroundStyle(viewModel.roleColor)
                    Text("You're a \(viewModel.roleLabel.lowercased()) of this list")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, DS.Spacing.sm)
                .background(viewModel.roleColor.opacity(0.1))
            }

            List {
                if !viewModel.urgentTasks.isEmpty {
                    taskSection(
                        tasks: viewModel.urgentTasks,
                        group: .urgent,
                        header: { Label("Urgent", systemImage: "flag.fill").foregroundStyle(DS.Colors.error).font(.caption) }
                    )
                }

                if !viewModel.starredTasks.isEmpty {
                    taskSection(
                        tasks: viewModel.starredTasks,
                        group: .starred,
                        header: { Label("Starred", systemImage: DS.Icon.starFilled).foregroundStyle(.yellow).font(.caption) }
                    )
                }

                if !viewModel.normalTasks.isEmpty {
                    taskSection(
                        tasks: viewModel.normalTasks,
                        group: .normal,
                        header: { Text("Tasks").font(.caption) }
                    )
                }

                if !viewModel.completedTasks.isEmpty {
                    taskSection(
                        tasks: viewModel.completedTasks,
                        group: nil,
                        header: { Text("Completed").font(.caption) }
                    )
                }
            }
            .listStyle(.plain)
            .surfaceFormBackground()
            .environment(\.editMode, viewModel.canEdit ? .constant(.active) : .constant(.inactive))
        }
    }

    private func taskSection<Header: View>(tasks: [TaskDTO], group: ListDetailViewModel.TaskGroup?, @ViewBuilder header: () -> Header) -> some View {
        Section {
            ForEach(tasks, id: \.id) { task in
                taskRowContainer(for: task)
            }
            .onMove { source, destination in
                if viewModel.canEdit, let group {
                    viewModel.moveTask(in: group, from: source, to: destination)
                }
            }
        } header: {
            header()
        }
    }

    private func taskRowContainer(for task: TaskDTO) -> TaskRowContainer {
        TaskRowContainer(
            task: task,
            canEdit: task.can_edit ?? viewModel.canEdit,
            canDelete: task.can_delete ?? viewModel.canEdit,
            isSharedList: viewModel.isSharedList,
            onComplete: { await viewModel.loadTasks() },
            onStar: { await viewModel.toggleStar(task) },
            onTap: { viewModel.selectedTask = task },
            onNudge: { await viewModel.nudgeAboutTask(task) },
            onDelete: { await viewModel.deleteTask(task) },
            onSubtaskComplete: { subtask in
                await viewModel.toggleSubtaskComplete(subtask: subtask, parentTask: task)
            },
            onSubtaskDelete: { subtask in
                await viewModel.deleteSubtask(subtask: subtask, parentTask: task)
            },
            onSubtaskEdit: { subtask in
                viewModel.startEditSubtask(subtask, parentTask: task)
            },
            onAddSubtask: {
                viewModel.startAddSubtask(for: task)
            }
        )
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
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .shadow(radius: 4)
            .padding(.bottom, DS.Spacing.xl)
    }
}

// MARK: - Response Types

struct NudgeResponse: Codable {
    let message: String
}
