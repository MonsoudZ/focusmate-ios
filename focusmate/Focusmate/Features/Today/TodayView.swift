import SwiftUI

struct TodayView: View {
    @StateObject private var viewModel: TodayViewModel

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
        _viewModel = StateObject(wrappedValue: vm)
    }

    var body: some View {
        NavigationStack {
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
                        viewModel.showingQuickAdd = true
                    } label: {
                        Image(systemName: DS.Icon.plus)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingQuickAdd) {
                QuickAddTaskView(
                    listService: viewModel.listService,
                    taskService: viewModel.taskService,
                    onTaskCreated: {
                        await viewModel.loadToday()
                    }
                )
            }
            .sheet(item: $viewModel.selectedTask) { task in
                TaskDetailView(
                    task: task,
                    listName: task.list_name ?? "Unknown",
                    onComplete: {
                        await viewModel.toggleComplete(task)
                        viewModel.selectedTask = nil
                    },
                    onDelete: {
                        await viewModel.deleteTask(task)
                        viewModel.selectedTask = nil
                    },
                    onUpdate: {
                        await viewModel.loadToday()
                    },
                    taskService: viewModel.taskService,
                    tagService: viewModel.tagService,
                    listId: task.list_id
                )
            }
        }
        .task {
            viewModel.initializeServiceIfNeeded()
            await viewModel.loadToday()
        }
    }

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
    }

    // MARK: - Escalation Banner

    @ViewBuilder
    private var escalationBanner: some View {
        if viewModel.screenTimeService.isBlocking {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: DS.Icon.lock)
                    .font(.title3)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Apps Blocked")
                        .font(.body.weight(.semibold))
                    Text("Complete your overdue tasks to unlock")
                        .font(.caption)
                }
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(DS.Spacing.md)
            .background(DS.Colors.error)
            .cornerRadius(DS.Radius.md)
        } else if viewModel.escalationService.isInGracePeriod {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: DS.Icon.timer)
                    .font(.title3)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Grace Period")
                        .font(.body.weight(.semibold))
                    Text("Apps will be blocked in \(viewModel.escalationService.gracePeriodRemainingFormatted ?? "...")")
                        .font(.caption)
                }
                Spacer()
            }
            .foregroundStyle(.black)
            .padding(DS.Spacing.md)
            .background(DS.Colors.warning)
            .cornerRadius(DS.Radius.md)
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
                        viewModel.isAllComplete ? DS.Colors.success : DS.Colors.accent,
                        style: StrokeStyle(lineWidth: DS.Size.progressStroke, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: viewModel.progress)

                if viewModel.isAllComplete {
                    Image(systemName: "checkmark")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(DS.Colors.success)
                } else {
                    Text("\(Int(viewModel.progress * 100))%")
                        .font(.title2.weight(.bold))
                }
            }
            .frame(width: DS.Size.progressRing, height: DS.Size.progressRing)

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.md) {
                    miniStat(count: viewModel.completedCount, total: viewModel.totalTasks, label: "Done")

                    if data.stats.overdue_count > 0 {
                        miniStat(count: data.stats.overdue_count, label: "Overdue", color: DS.Colors.error)
                    }
                }

                if let streak = data.streak {
                    HStack(spacing: DS.Spacing.xs) {
                        Text("🔥")
                        if streak.current > 0 {
                            Text("\(streak.current) day streak")
                                .font(.subheadline.weight(.medium))
                        } else {
                            Text("Complete all tasks to start a streak!")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(DS.Spacing.md)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(DS.Radius.md)
    }

    private func miniStat(count: Int, total: Int? = nil, label: String, color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            if let total = total {
                Text("\(count)/\(total)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color ?? .primary)
            } else {
                Text("\(count)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color ?? .primary)
            }
            Text(label)
                .font(.caption2)
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
                    .font(.title3.weight(.semibold))
                Text("(\(tasks.count))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(tasks) { task in
                TaskRow(
                    task: task,
                    onComplete: { await viewModel.loadToday() },
                    onTap: { viewModel.selectedTask = task }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Empty States

    private var allClearView: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: DS.Icon.checkSeal)
                .font(.system(size: DS.Size.iconJumbo))
                .foregroundStyle(DS.Colors.success)
            Text("All Clear!")
                .font(.title2.weight(.semibold))
            Text("You've completed all your tasks for today!")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(DS.Spacing.xl)
    }

    private var nothingDueView: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: DS.Icon.calendar)
                .font(.system(size: DS.Size.iconJumbo))
                .foregroundStyle(.secondary)
            Text("Nothing Due Today")
                .font(.title2.weight(.semibold))
            Text("Enjoy your free day or plan ahead!")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(DS.Spacing.xl)
    }

    private var emptyView: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: DS.Icon.emptyTray)
                .font(.system(size: DS.Size.iconJumbo))
                .foregroundStyle(.secondary)
            Text("No tasks yet")
                .font(.title2.weight(.semibold))
            Text("Create a task to get started")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(_ error: FocusmateError) -> some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: DS.Icon.overdue)
                .font(.system(size: DS.Size.iconJumbo))
                .foregroundStyle(DS.Colors.error)
            Text("Something went wrong")
                .font(.title2.weight(.semibold))
            Button("Try Again") {
                Task { await viewModel.loadToday() }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
