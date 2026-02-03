import SwiftUI

struct ListDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.router) private var router

    @State private var viewModel: ListDetailViewModel

    init(list: ListDTO, taskService: TaskService, listService: ListService, tagService: TagService, inviteService: InviteService, friendService: FriendService, subtaskManager: SubtaskManager) {
        _viewModel = State(initialValue: ListDetailViewModel(
            list: list,
            taskService: taskService,
            listService: listService,
            tagService: tagService,
            inviteService: inviteService,
            friendService: friendService,
            subtaskManager: subtaskManager
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
        .alert("Delete List", isPresented: $viewModel.showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteList() }
            }
        } message: {
            Text("Are you sure you want to delete '\(viewModel.list.name)'? This action cannot be undone.")
        }
        .floatingErrorBanner($viewModel.error) {
            await viewModel.loadTasks()
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

    // MARK: - Sheet Presentation

    private func presentCreateTask() {
        router.sheetCallbacks.onTaskCreated = {
            await viewModel.loadTasks()
        }
        router.present(.createTask(listId: viewModel.list.id))
    }

    private func presentEditList() {
        router.sheetCallbacks.onListUpdated = {
            await viewModel.loadTasks()
        }
        router.present(.editList(viewModel.list))
    }

    private func presentMembers() {
        router.present(.listMembers(viewModel.list))
    }

    private func presentTaskDetail(_ task: TaskDTO) {
        router.sheetCallbacks.onTaskCompleted = { task in
            await viewModel.toggleComplete(task)
            router.dismissSheet()
        }
        router.sheetCallbacks.onTaskDeleted = { task in
            await viewModel.deleteTask(task)
            router.dismissSheet()
        }
        router.sheetCallbacks.onTaskUpdated = {
            await viewModel.loadTasks()
        }
        router.present(.taskDetail(task, listName: viewModel.list.name))
    }

    private func presentAddSubtask(for task: TaskDTO) {
        router.sheetCallbacks.onSubtaskCreated = { parentTask, title in
            await viewModel.createSubtask(parentTask: parentTask, title: title)
        }
        router.present(.addSubtask(task))
    }

    private func presentEditSubtask(_ subtask: SubtaskDTO, parentTask: TaskDTO) {
        let info = SubtaskEditInfo(subtask: subtask, parentTask: parentTask)
        router.sheetCallbacks.onSubtaskUpdated = { info, title in
            await viewModel.updateSubtask(info: info, title: title)
        }
        router.present(.editSubtask(info))
    }

    private func presentInvites() {
        router.push(.listInvites(viewModel.list))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if viewModel.isOwner {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    presentInvites()
                } label: {
                    Image(systemName: "person.badge.plus")
                }
                .accessibilityLabel("Invite to list")
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                if viewModel.canEdit {
                    Button {
                        presentCreateTask()
                    } label: {
                        Label("Add Task", systemImage: DS.Icon.plus)
                    }

                    Divider()
                }

                Button {
                    presentMembers()
                } label: {
                    Label("Members", systemImage: "person.2")
                }

                if viewModel.isOwner {
                    Button {
                        presentEditList()
                    } label: {
                        Label("Edit List", systemImage: DS.Icon.edit)
                    }

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

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        if viewModel.canEdit {
            EmptyState(
                "No tasks yet",
                message: "Add your first task to get started",
                icon: DS.Icon.circle,
                actionTitle: "Add Task",
                action: { presentCreateTask() }
            )
        } else {
            EmptyState(
                "No tasks yet",
                message: "The owner hasn't added any tasks to this list",
                icon: DS.Icon.circle
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
            onComplete: { viewModel.markTaskCompleted(task.id) },
            onStar: { await viewModel.toggleStar(task) },
            onTap: { presentTaskDetail(task) },
            onNudge: { await viewModel.nudgeAboutTask(task) },
            onDelete: { await viewModel.deleteTask(task) },
            onSubtaskEdit: { subtask in
                presentEditSubtask(subtask, parentTask: task)
            },
            onAddSubtask: {
                presentAddSubtask(for: task)
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
    let onSubtaskEdit: (SubtaskDTO) -> Void
    let onAddSubtask: () -> Void

    var body: some View {
        TaskRow(
            task: task,
            onComplete: onComplete,
            onStar: onStar,
            onTap: onTap,
            onNudge: onNudge,
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

