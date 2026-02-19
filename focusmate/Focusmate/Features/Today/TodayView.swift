import SwiftUI

struct TodayView: View {
    @State private var viewModel: TodayViewModel
    @Environment(\.router) private var router
    @EnvironmentObject private var appState: AppState

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
            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.error {
                TodayErrorView(error: error) {
                    await viewModel.loadToday()
                }
            } else if let data = viewModel.todayData {
                contentView(data)
            } else {
                TodayEmptyView()
            }
        }
        .navigationTitle("Today, \(Date().formatted(.dateTime.month(.abbreviated).day()))")
        .refreshable {
            await viewModel.loadToday()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    presentQuickAdd()
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
                        withAnimation {
                            viewModel.nudgeMessage = nil
                        }
                    }
            }
        }
        .animation(.easeInOut, value: viewModel.nudgeMessage)
        .task {
            viewModel.initializeServiceIfNeeded()
            await viewModel.loadToday()
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
        router.sheetCallbacks.onTaskCreated = {
            await viewModel.loadToday()
        }
        router.present(.quickAddTask)
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
            await viewModel.loadToday()
        }
        router.present(.taskDetail(task, listName: task.list_name ?? "Unknown"))
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

    // MARK: - Content Views

    private func contentView(_ data: TodayResponse) -> some View {
        let grouped = viewModel.groupedTasks
        return ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                OfflineBanner(
                    isConnected: NetworkMonitor.shared.isConnected,
                    pendingCount: NetworkMonitor.shared.pendingMutationCount
                )

                TodayEscalationBanner(
                    isBlocking: viewModel.screenTimeService.isBlocking,
                    isInGracePeriod: viewModel.escalationService.isInGracePeriod,
                    gracePeriodRemaining: viewModel.escalationService.gracePeriodRemainingFormatted,
                    authorizationWasRevoked: viewModel.escalationService.authorizationWasRevoked,
                    onRevocationBannerTapped: {
                        // Navigation handled in the view (not ViewModel) because router
                        // is @Environment — follows the existing pattern for presentQuickAdd().
                        viewModel.escalationService.clearAuthorizationRevocationFlag()
                        router.push(.appBlockingSettings, in: .settings)
                        router.switchTab(to: .settings)
                    }
                )

                TodayProgressSection(
                    progress: viewModel.progress,
                    isAllComplete: viewModel.isAllComplete,
                    completedCount: viewModel.completedCount,
                    totalTasks: viewModel.totalTasks,
                    overdueCount: data.stats?.overdue_count ?? 0,
                    streak: data.streak
                )

                if !data.overdue.isEmpty {
                    taskSection(
                        title: "Overdue",
                        icon: DS.Icon.overdue,
                        iconColor: DS.Colors.error,
                        tasks: data.overdue
                    )
                }

                if !grouped.anytime.isEmpty {
                    taskSection(
                        title: "Anytime Today",
                        icon: DS.Icon.calendar,
                        iconColor: DS.Colors.accent,
                        tasks: grouped.anytime
                    )
                }

                if !grouped.morning.isEmpty {
                    taskSection(
                        title: "Morning",
                        icon: DS.Icon.morning,
                        iconColor: DS.Colors.morning,
                        tasks: grouped.morning
                    )
                }

                if !grouped.afternoon.isEmpty {
                    taskSection(
                        title: "Afternoon",
                        icon: DS.Icon.afternoon,
                        iconColor: DS.Colors.afternoon,
                        tasks: grouped.afternoon
                    )
                }

                if !grouped.evening.isEmpty {
                    taskSection(
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
                                withAnimation {
                                    viewModel.hideCompleted.toggle()
                                }
                            } label: {
                                Image(systemName: viewModel.hideCompleted ? "eye.slash" : "eye")
                                    .font(.system(size: 16))
                                    .foregroundStyle(DS.Colors.accent)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(viewModel.hideCompleted ? "Show completed tasks" : "Hide completed tasks")
                        }

                        if !viewModel.hideCompleted {
                            ForEach(data.completed_today) { task in
                                TaskRow(
                                    task: task,
                                    onComplete: { await viewModel.toggleComplete(task) },
                                    onStar: { await viewModel.toggleStar(task) },
                                    onTap: { presentTaskDetail(task) },
                                    onNudge: { await viewModel.nudgeTask(task) },
                                    onSubtaskEdit: { subtask in
                                        presentEditSubtask(subtask, parentTask: task)
                                    },
                                    onAddSubtask: {
                                        presentAddSubtask(for: task)
                                    },
                                    showStar: task.can_edit ?? true,
                                    showNudge: shouldShowNudge(for: task)
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if viewModel.isAllComplete {
                    TodayAllClearView()
                } else if data.overdue.isEmpty && data.due_today.isEmpty && data.completed_today.isEmpty {
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
                    onComplete: { await viewModel.toggleComplete(task) },
                    onStar: { await viewModel.toggleStar(task) },
                    onTap: { presentTaskDetail(task) },
                    onNudge: { await viewModel.nudgeTask(task) },
                    onSubtaskEdit: { subtask in
                        presentEditSubtask(subtask, parentTask: task)
                    },
                    onAddSubtask: {
                        presentAddSubtask(for: task)
                    },
                    showStar: task.can_edit ?? true,
                    showNudge: shouldShowNudge(for: task)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
