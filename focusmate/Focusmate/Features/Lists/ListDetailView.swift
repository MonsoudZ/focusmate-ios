import SwiftUI

struct ListDetailView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.router) private var router

  @State private var viewModel: ListDetailViewModel

  init(
    list: ListDTO,
    taskService: TaskService,
    listService: ListService,
    tagService: TagService,
    inviteService: InviteService,
    friendService: FriendService,
    subtaskManager: SubtaskManager
  ) {
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
      if self.viewModel.isLoading, self.viewModel.tasks.isEmpty {
        TasksLoadingView()
      } else if self.viewModel.tasks.isEmpty {
        self.emptyStateView
      } else {
        self.taskListView
      }
    }
    .navigationTitle(self.viewModel.list.name)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar { self.toolbarContent }
    .alert("Delete List", isPresented: self.$viewModel.showingDeleteConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Delete", role: .destructive) {
        Task { await self.viewModel.deleteList() }
      }
    } message: {
      Text("Are you sure you want to delete '\(self.viewModel.list.name)'? This action cannot be undone.")
    }
    .floatingErrorBanner(self.$viewModel.error) {
      await self.viewModel.loadTasks()
    }
    .overlay(alignment: .bottom) {
      if let message = viewModel.nudgeMessage {
        NudgeToast(message: message)
          .transition(.move(edge: .bottom).combined(with: .opacity))
          .task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
              self.viewModel.nudgeMessage = nil
            }
          }
      }
    }
    .task {
      await self.viewModel.loadTasks()
    }
    .refreshable {
      HapticManager.light()
      await self.viewModel.loadTasks()
    }
    .onAppear {
      self.viewModel.onDismiss = { self.dismiss() }
    }
  }

  // MARK: - Sheet Presentation

  private func presentCreateTask() {
    self.router.sheetCallbacks.onTaskCreated = {
      await self.viewModel.loadTasks()
    }
    self.router.present(.createTask(listId: self.viewModel.list.id))
  }

  private func presentEditList() {
    self.router.sheetCallbacks.onListUpdated = {
      await self.viewModel.loadTasks()
    }
    self.router.present(.editList(self.viewModel.list))
  }

  private func presentMembers() {
    self.router.present(.listMembers(self.viewModel.list))
  }

  private func presentTaskDetail(_ task: TaskDTO) {
    self.router.sheetCallbacks.onTaskCompleted = { task in
      await self.viewModel.toggleComplete(task)
      self.router.dismissSheet()
    }
    self.router.sheetCallbacks.onTaskDeleted = { task in
      await self.viewModel.deleteTask(task)
      self.router.dismissSheet()
    }
    self.router.sheetCallbacks.onTaskUpdated = {
      await self.viewModel.loadTasks()
    }
    self.router.present(.taskDetail(task, listName: self.viewModel.list.name))
  }

  private func presentAddSubtask(for task: TaskDTO) {
    self.router.sheetCallbacks.onSubtaskCreated = { parentTask, title in
      await self.viewModel.createSubtask(parentTask: parentTask, title: title)
    }
    self.router.present(.addSubtask(task))
  }

  private func presentEditSubtask(_ subtask: SubtaskDTO, parentTask: TaskDTO) {
    let info = SubtaskEditInfo(subtask: subtask, parentTask: parentTask)
    self.router.sheetCallbacks.onSubtaskUpdated = { info, title in
      await self.viewModel.updateSubtask(info: info, title: title)
    }
    self.router.present(.editSubtask(info))
  }

  private func presentInvites() {
    self.router.push(.listInvites(self.viewModel.list))
  }

  // MARK: - Toolbar

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    if self.viewModel.isSharedList, !self.viewModel.isOwner {
      ToolbarItem(placement: .navigationBarLeading) {
        Label(self.viewModel.roleLabel, systemImage: self.viewModel.roleIcon)
          .font(.caption2)
          .foregroundStyle(self.viewModel.roleColor)
      }
    }

    ToolbarItem(placement: .navigationBarTrailing) {
      Menu {
        if self.viewModel.canEdit {
          Button {
            self.presentCreateTask()
          } label: {
            Label("Add Task", systemImage: DS.Icon.plus)
          }

          Divider()
        }

        Button {
          self.presentMembers()
        } label: {
          Label("Members", systemImage: "person.2")
        }

        if self.viewModel.isOwner {
          Button {
            self.presentInvites()
          } label: {
            Label("Invite Links", systemImage: "link.badge.plus")
          }

          Button {
            self.presentEditList()
          } label: {
            Label("Edit List", systemImage: DS.Icon.edit)
          }

          Divider()

          Button(role: .destructive) {
            self.viewModel.showingDeleteConfirmation = true
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
    if self.viewModel.canEdit {
      EmptyState(
        "No tasks yet",
        message: "Add your first task to get started",
        icon: DS.Icon.circle,
        actionTitle: "Add Task",
        action: { self.presentCreateTask() }
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

  // MARK: - List Header

  private var listHeaderView: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      if let description = viewModel.list.description, !description.isEmpty {
        Text(description)
          .font(DS.Typography.subheadline)
          .foregroundStyle(.secondary)
      }

      HStack(spacing: DS.Spacing.lg) {
        // Task progress
        let totalTasks = self.viewModel.urgentTasks.count + self.viewModel.starredTasks.count
          + self.viewModel.normalTasks.count + self.viewModel.completedCount
        if totalTasks > 0 {
          HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "checkmark.circle")
              .font(.caption)
              .foregroundStyle(DS.Colors.success)
            Text("\(self.viewModel.completedCount)/\(totalTasks)")
              .font(DS.Typography.caption)
              .foregroundStyle(.secondary)
          }
        }

        // Member count
        if let members = viewModel.list.members, members.count > 1 {
          HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "person.2")
              .font(.caption)
              .foregroundStyle(.secondary)
            Text("\(members.count) members")
              .font(DS.Typography.caption)
              .foregroundStyle(.secondary)
          }
        }

        // List type
        if let listType = viewModel.list.list_type, listType != "tasks" {
          Text(listType == "habit_tracker" ? "Habit Tracker" : listType.capitalized)
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Colors.accent)
        }
      }
    }
    .padding(.horizontal, DS.Spacing.lg)
    .padding(.vertical, DS.Spacing.sm)
  }

  private var taskListView: some View {
    VStack(spacing: 0) {
      OfflineBanner(
        isConnected: NetworkMonitor.shared.isConnected,
        pendingCount: NetworkMonitor.shared.pendingMutationCount
      )

      self.listHeaderView

      List {
        if !self.viewModel.urgentTasks.isEmpty {
          self.taskSection(
            tasks: self.viewModel.urgentTasks,
            group: .urgent,
            header: { Label("Urgent", systemImage: "flag.fill").foregroundStyle(DS.Colors.error).font(.caption) }
          )
        }

        if !self.viewModel.starredTasks.isEmpty {
          self.taskSection(
            tasks: self.viewModel.starredTasks,
            group: .starred,
            header: { Label("Starred", systemImage: DS.Icon.starFilled).foregroundStyle(.yellow).font(.caption) }
          )
        }

        if !self.viewModel.normalTasks.isEmpty {
          self.taskSection(
            tasks: self.viewModel.normalTasks,
            group: .normal,
            header: { Text("Tasks").font(.caption) }
          )
        }

        if self.viewModel.completedCount > 0 {
          Section {
            if !self.viewModel.hideCompleted {
              ForEach(self.viewModel.completedTasks, id: \.id) { task in
                self.taskRowContainer(for: task)
              }
            }
          } header: {
            HStack {
              Text("Completed (\(self.viewModel.completedCount))")
                .font(.caption)
              Spacer()
              Button {
                withAnimation {
                  self.viewModel.hideCompleted.toggle()
                }
              } label: {
                Image(systemName: self.viewModel.hideCompleted ? "eye.slash" : "eye")
                  .font(.caption)
                  .foregroundStyle(DS.Colors.accent)
              }
              .buttonStyle(.plain)
              .accessibilityLabel(self.viewModel.hideCompleted ? "Show completed tasks" : "Hide completed tasks")
            }
          }
        }
      }
      .listStyle(.plain)
      .surfaceFormBackground()
      .environment(\.editMode, .constant(self.viewModel.canEdit ? .active : .inactive))
    }
  }

  private func taskSection(
    tasks: [TaskDTO],
    group: ListDetailViewModel.TaskGroup?,
    @ViewBuilder header: () -> some View
  ) -> some View {
    Section {
      ForEach(tasks, id: \.id) { task in
        self.taskRowContainer(for: task)
      }
      .onMove { source, destination in
        if self.viewModel.canEdit, let group {
          self.viewModel.moveTask(in: group, from: source, to: destination)
        }
      }
    } header: {
      header()
    }
  }

  private func taskRowContainer(for task: TaskDTO) -> TaskRowContainer {
    let taskCanEdit = !task.isCompleted && (task.can_edit ?? self.viewModel.canEdit)
    return TaskRowContainer(
      task: task,
      canEdit: taskCanEdit,
      canDelete: task.can_delete ?? self.viewModel.canEdit,
      isSharedList: self.viewModel.isSharedList,
      onComplete: { self.viewModel.markTaskCompleted(task.id) },
      onStar: { await self.viewModel.toggleStar(task) },
      onTap: { self.presentTaskDetail(task) },
      onNudge: { await self.viewModel.nudgeAboutTask(task) },
      onHide: { await self.viewModel.toggleHidden(task) },
      onDelete: { await self.viewModel.deleteTask(task) },
      onSubtaskEdit: { subtask in
        self.presentEditSubtask(subtask, parentTask: task)
      },
      onAddSubtask: {
        self.presentAddSubtask(for: task)
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
  let onHide: () async -> Void
  let onDelete: () async -> Void
  let onSubtaskEdit: (SubtaskDTO) -> Void
  let onAddSubtask: () -> Void

  var body: some View {
    TaskRow(
      task: self.task,
      onComplete: self.onComplete,
      onStar: self.onStar,
      onTap: self.onTap,
      onNudge: self.onNudge,
      onHide: self.onHide,
      onSubtaskEdit: self.onSubtaskEdit,
      onAddSubtask: self.onAddSubtask,
      showStar: self.canEdit,
      showNudge: self.isSharedList,
      showHide: self.isSharedList && self.canEdit
    )
    .listRowInsets(EdgeInsets(
      top: DS.Spacing.xs,
      leading: DS.Spacing.lg,
      bottom: DS.Spacing.xs,
      trailing: DS.Spacing.lg
    ))
    .listRowSeparator(.hidden)
    .listRowBackground(Color.clear)
    .swipeActions(edge: .trailing, allowsFullSwipe: self.canDelete) {
      if self.canDelete {
        Button("Delete", role: .destructive) {
          HapticManager.warning()
          Task { await self.onDelete() }
        }
      }
    }
    .swipeActions(edge: .leading, allowsFullSwipe: false) {
      if self.isSharedList, self.canEdit {
        Button {
          Task { await self.onHide() }
        } label: {
          Label(
            self.task.isHidden ? "Show" : "Hide",
            systemImage: self.task.isHidden ? "eye" : "eye.slash"
          )
        }
        .tint(self.task.isHidden ? DS.Colors.success : Color(.systemGray))
      }

      if self.isSharedList {
        Button {
          Task { await self.onNudge() }
        } label: {
          Label("Nudge", systemImage: "hand.point.right.fill")
        }
        .tint(DS.Colors.accent)
      }
    }
  }
}
