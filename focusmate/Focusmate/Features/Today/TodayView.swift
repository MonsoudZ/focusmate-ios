import SwiftUI

struct TodayView: View {
  @State private var viewModel: TodayViewModel
  @Environment(\.router) private var router
  @Environment(AppState.self) private var appState

  init(
    taskService: TaskService,
    listService: ListService,
    tagService: TagService,
    apiClient: APIClient,
    subtaskManager: SubtaskManager,
    escalationService: EscalationService? = nil,
    screenTimeService: (any ScreenTimeManaging)? = nil,
    onOverdueCountChange: ((Int) -> Void)? = nil
  ) {
    let vm = TodayViewModel(
      taskService: taskService,
      listService: listService,
      tagService: tagService,
      apiClient: apiClient,
      subtaskManager: subtaskManager,
      escalationService: escalationService,
      screenTimeService: screenTimeService
    )
    vm.onOverdueCountChange = onOverdueCountChange
    _viewModel = State(initialValue: vm)
  }

  var body: some View {
    Group {
      if self.viewModel.isLoading {
        ProgressView()
      } else if let error = viewModel.error {
        TodayErrorView(error: error) {
          await self.viewModel.loadToday()
        }
      } else if let data = viewModel.todayData {
        self.contentView(data)
      } else {
        TodayEmptyView()
      }
    }
    .navigationTitle("Today, \(Date().formatted(.dateTime.month(.abbreviated).day()))")
    .refreshable {
      await self.viewModel.loadToday()
    }
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button {
          self.presentQuickAdd()
        } label: {
          Image(systemName: DS.Icon.plus)
        }
      }
    }
    .overlay(alignment: .bottom) {
      if let message = viewModel.nudgeMessage {
        NudgeToast(message: message)
          .transition(.move(edge: .bottom).combined(with: .opacity))
          .task {
            try? await Task.sleep(for: .seconds(2))
            withMotionAnimation {
              self.viewModel.nudgeMessage = nil
            }
          }
      }
    }
    .animateIfAllowed(.easeInOut, value: self.viewModel.nudgeMessage)
    .task {
      self.viewModel.initializeServiceIfNeeded()
      await self.viewModel.loadToday()
    }
  }

  // MARK: - Helpers

  /// Only show nudge if the task has a creator who is NOT the current user.
  /// Nudging your own tasks is meaningless — nudge is for reminding others.
  private func shouldShowNudge(for task: TaskDTO) -> Bool {
    guard let creator = task.creator else { return false }
    guard let currentUserId = appState.auth.currentUser?.id else { return false }
    return creator.id != currentUserId
  }

  // MARK: - Sheet Presentation

  private func presentQuickAdd() {
    self.router.sheetCallbacks.onTaskCreated = {
      await self.viewModel.loadToday()
    }
    self.router.present(.quickAddTask)
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
      await self.viewModel.loadToday()
    }
    self.router.present(.taskDetail(task, listName: task.list_name ?? "Unknown"))
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

  // MARK: - Content Views

  // swiftlint:disable:next function_body_length
  private func contentView(_ data: TodayResponse) -> some View {
    let grouped = self.viewModel.groupedTasks
    return ScrollView {
      VStack(spacing: DS.Spacing.lg) {
        OfflineBanner(
          isConnected: NetworkMonitor.shared.isConnected,
          pendingCount: NetworkMonitor.shared.pendingMutationCount
        )

        TodayEscalationBanner(
          isBlocking: self.viewModel.screenTimeService.isBlocking,
          isInGracePeriod: self.viewModel.escalationService.isInGracePeriod,
          gracePeriodRemaining: self.viewModel.escalationService.gracePeriodRemainingFormatted,
          authorizationWasRevoked: self.viewModel.escalationService.authorizationWasRevoked,
          onRevocationBannerTapped: {
            // Navigation handled in the view (not ViewModel) because router
            // is @Environment — follows the existing pattern for presentQuickAdd().
            self.viewModel.escalationService.clearAuthorizationRevocationFlag()
            self.router.push(.appBlockingSettings, in: .settings)
            self.router.switchTab(to: .settings)
          }
        )

        TodayProgressSection(
          progress: self.viewModel.progress,
          isAllComplete: self.viewModel.isAllComplete,
          completedCount: self.viewModel.completedCount,
          totalTasks: self.viewModel.totalTasks,
          overdueCount: data.stats?.overdue_count ?? 0,
          streak: data.streak
        )

        if !data.overdue.isEmpty {
          self.taskSection(
            title: "Overdue",
            icon: DS.Icon.overdue,
            iconColor: DS.Colors.error,
            tasks: data.overdue
          )
        }

        if !grouped.anytime.isEmpty {
          self.taskSection(
            title: "Anytime Today",
            icon: DS.Icon.calendar,
            iconColor: DS.Colors.accent,
            tasks: grouped.anytime
          )
        }

        if !grouped.morning.isEmpty {
          self.taskSection(
            title: "Morning",
            icon: DS.Icon.morning,
            iconColor: DS.Colors.morning,
            tasks: grouped.morning
          )
        }

        if !grouped.afternoon.isEmpty {
          self.taskSection(
            title: "Afternoon",
            icon: DS.Icon.afternoon,
            iconColor: DS.Colors.afternoon,
            tasks: grouped.afternoon
          )
        }

        if !grouped.evening.isEmpty {
          self.taskSection(
            title: "Evening",
            icon: DS.Icon.evening,
            iconColor: DS.Colors.evening,
            tasks: grouped.evening
          )
        }

        if !data.completed_today.isEmpty {
          VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
              Image(systemName: DS.Icon.circleChecked)
                .foregroundStyle(DS.Colors.success)
              Text("Completed")
                .font(DS.Typography.title3)
              Text("(\(data.completed_today.count))")
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
              Spacer()
              Button {
                withMotionAnimation {
                  self.viewModel.hideCompleted.toggle()
                }
              } label: {
                Image(systemName: self.viewModel.hideCompleted ? "eye.slash" : "eye")
                  .scaledFont(size: 16, relativeTo: .callout)
                  .foregroundStyle(DS.Colors.accent)
              }
              .buttonStyle(.plain)
              .accessibilityLabel(self.viewModel.hideCompleted ? "Show completed tasks" : "Hide completed tasks")
            }

            if !self.viewModel.hideCompleted {
              ForEach(data.completed_today) { task in
                TaskRow(
                  task: task,
                  onComplete: { await self.viewModel.toggleComplete(task) },
                  onStar: { await self.viewModel.toggleStar(task) },
                  onTap: { self.presentTaskDetail(task) },
                  onNudge: { await self.viewModel.nudgeTask(task) },
                  onDelete: { await self.viewModel.deleteTask(task) },
                  onSubtaskEdit: { subtask in
                    self.presentEditSubtask(subtask, parentTask: task)
                  },
                  onAddSubtask: {
                    self.presentAddSubtask(for: task)
                  },
                  showStar: task.can_edit ?? true,
                  showNudge: self.shouldShowNudge(for: task),
                  showDelete: task.can_delete ?? true
                )
              }
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }

        if self.viewModel.isAllComplete {
          TodayAllClearView()
        } else if data.overdue.isEmpty, data.due_today.isEmpty, data.completed_today.isEmpty {
          TodayNothingDueView()
        }
      }
      .padding(DS.Spacing.lg)
    }
    .surfaceBackground()
  }

  // MARK: - Task Section

  private func taskSection(title: String, icon: String, iconColor: Color, tasks: [TaskDTO]) -> some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      HStack(spacing: DS.Spacing.xs) {
        Image(systemName: icon)
          .foregroundStyle(iconColor)
        Text(title)
          .font(DS.Typography.title3)
        Text("(\(tasks.count))")
          .font(DS.Typography.subheadline)
          .foregroundStyle(.secondary)
      }

      ForEach(tasks) { task in
        TaskRow(
          task: task,
          onComplete: { await self.viewModel.toggleComplete(task) },
          onStar: { await self.viewModel.toggleStar(task) },
          onTap: { self.presentTaskDetail(task) },
          onNudge: { await self.viewModel.nudgeTask(task) },
          onDelete: { await self.viewModel.deleteTask(task) },
          onSubtaskEdit: { subtask in
            self.presentEditSubtask(subtask, parentTask: task)
          },
          onAddSubtask: {
            self.presentAddSubtask(for: task)
          },
          showStar: task.can_edit ?? true,
          showNudge: self.shouldShowNudge(for: task),
          showDelete: task.can_delete ?? true
        )
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
