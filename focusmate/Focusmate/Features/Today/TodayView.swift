import SwiftUI

struct TodayView: View {
    @State private var viewModel: TodayViewModel
    @Environment(\.router) private var router

    init(
        taskService: TaskService,
        listService: ListService,
        tagService: TagService,
        apiClient: APIClient,
        escalationService: EscalationService? = nil,
        screenTimeService: ScreenTimeService? = nil,
        onOverdueCountChange: ((Int) -> Void)? = nil
    ) {
        let vm = TodayViewModel(
            taskService: taskService,
            listService: listService,
            tagService: tagService,
            apiClient: apiClient,
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
                errorView(error)
            } else if let data = viewModel.todayData {
                contentView(data)
            } else {
                emptyView
            }
        }
        .navigationTitle("Today")
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
        .task {
            viewModel.initializeServiceIfNeeded()
            await viewModel.loadToday()
        }
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
                escalationBanner

                progressSection(data)

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
                    taskSection(
                        title: "Completed",
                        icon: DS.Icon.circleChecked,
                        iconColor: DS.Colors.success,
                        tasks: data.completed_today
                    )
                }

                if viewModel.isAllComplete {
                    allClearView
                } else if data.overdue.isEmpty && data.due_today.isEmpty && data.completed_today.isEmpty {
                    nothingDueView
                }
            }
            .padding(DS.Spacing.lg)
        }
        .surfaceBackground()
    }

    // MARK: - Escalation Banner

    @ViewBuilder
    private var escalationBanner: some View {
        if viewModel.screenTimeService.isBlocking {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: DS.Icon.lock)
                    .font(DS.Typography.title3)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Apps Blocked")
                        .font(DS.Typography.bodyMedium)
                    Text("Complete your overdue tasks to unlock")
                        .font(DS.Typography.caption)
                }
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(DS.Spacing.md)
            .background(
                LinearGradient(
                    colors: [DS.Colors.error, DS.Colors.error.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        } else if viewModel.escalationService.isInGracePeriod {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: DS.Icon.timer)
                    .font(DS.Typography.title3)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Grace Period")
                        .font(DS.Typography.bodyMedium)
                    Text("Apps will be blocked in \(viewModel.escalationService.gracePeriodRemainingFormatted ?? "...")")
                        .font(DS.Typography.caption)
                }
                Spacer()
            }
            .foregroundStyle(.black)
            .padding(DS.Spacing.md)
            .background(
                LinearGradient(
                    colors: [DS.Colors.warning, DS.Colors.warning.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        }
    }

    // MARK: - Progress Section

    private func progressSection(_ data: TodayResponse) -> some View {
        HStack(spacing: DS.Spacing.lg) {
            // Progress Ring
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: DS.Size.progressStroke)

                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(
                        viewModel.isAllComplete
                            ? AnyShapeStyle(DS.Colors.success)
                            : AnyShapeStyle(
                                AngularGradient(
                                    colors: [DS.Colors.accent.opacity(0.6), DS.Colors.accent],
                                    center: .center,
                                    startAngle: .degrees(-90),
                                    endAngle: .degrees(-90 + 360 * viewModel.progress)
                                )
                            ),
                        style: StrokeStyle(lineWidth: DS.Size.progressStroke, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: viewModel.progress)

                if viewModel.isAllComplete {
                    Image(systemName: "checkmark")
                        .font(DS.Typography.title2)
                        .foregroundStyle(DS.Colors.success)
                } else {
                    Text("\(Int(viewModel.progress * 100))%")
                        .font(DS.Typography.title2)
                }
            }
            .frame(width: DS.Size.progressRing, height: DS.Size.progressRing)

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.md) {
                    miniStat(count: viewModel.completedCount, total: viewModel.totalTasks, label: "Done")

                    if (data.stats?.overdue_count ?? 0) > 0 {
                        miniStat(count: data.stats?.overdue_count ?? 0, label: "Overdue", color: DS.Colors.error)
                    }
                }

                HStack(spacing: DS.Spacing.xs) {
                    Text("🔥")
                    if let streak = data.streak, streak.current > 0 {
                        Text("\(streak.current) day streak")
                            .font(DS.Typography.subheadline.weight(.medium))
                    } else {
                        Text("Complete all tasks to start a streak!")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .heroCard()
    }

    private func miniStat(count: Int, total: Int? = nil, label: String, color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            if let total = total {
                Text("\(count)/\(total)")
                    .font(DS.Typography.title3)
                    .foregroundStyle(color ?? .primary)
            } else {
                Text("\(count)")
                    .font(DS.Typography.title3)
                    .foregroundStyle(color ?? .primary)
            }
            Text(label)
                .font(DS.Typography.caption2)
                .foregroundStyle(.secondary)
        }
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
                    onComplete: { await viewModel.loadToday() },
                    onTap: { presentTaskDetail(task) },
                    onSubtaskEdit: { subtask in
                        presentEditSubtask(subtask, parentTask: task)
                    },
                    onAddSubtask: {
                        presentAddSubtask(for: task)
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Empty States

    private var allClearView: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: DS.Icon.checkSeal)
                .font(.system(size: 64))
                .foregroundStyle(DS.Colors.success)
            Text("All Clear!")
                .font(DS.Typography.title2)
            Text("You've completed all your tasks for today!")
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(DS.Spacing.xl)
    }

    private var nothingDueView: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: DS.Icon.calendar)
                .font(.system(size: 64))
                .foregroundStyle(DS.Colors.accent)
            Text("Nothing Due Today")
                .font(DS.Typography.title2)
            Text("Enjoy your free day or plan ahead!")
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
        }
        .padding(DS.Spacing.xl)
    }

    private var emptyView: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: DS.Icon.emptyTray)
                .font(.system(size: 64))
                .foregroundStyle(DS.Colors.accent)
            Text("No tasks yet")
                .font(DS.Typography.title2)
            Text("Create a task to get started")
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(_ error: FocusmateError) -> some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: DS.Icon.overdue)
                .font(.system(size: 64))
                .foregroundStyle(DS.Colors.error)
            Text("Something went wrong")
                .font(DS.Typography.title2)
            Button("Try Again") {
                Task { await viewModel.loadToday() }
            }
            .buttonStyle(IntentiaPrimaryButtonStyle())
        }
    }
}
