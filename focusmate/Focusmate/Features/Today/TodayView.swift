import SwiftUI
import Combine

struct TodayView: View {
    @EnvironmentObject var state: AppState
    @State private var todayData: TodayResponse?
    @State private var isLoading = true
    @State private var error: FocusmateError?
    @State private var showingQuickAdd = false
    @State private var isBlocking = false
    @State private var isInGracePeriod = false
    @State private var gracePeriodRemaining: String?
    @State private var selectedTask: TaskDTO?
    
    var onOverdueCountChange: ((Int) -> Void)? = nil
    
    private var todayService: TodayService {
        TodayService(api: state.auth.api)
    }
    
    // MARK: - Progress Calculation
    
    private var totalTasks: Int {
        guard let data = todayData else { return 0 }
        return data.overdue.count + data.due_today.count + data.completed_today.count
    }
    
    private var completedCount: Int {
        todayData?.completed_today.count ?? 0
    }
    
    private var progress: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedCount) / Double(totalTasks)
    }
    
    private var isAllComplete: Bool {
        guard let data = todayData else { return false }
        return data.overdue.isEmpty && data.due_today.isEmpty && !data.completed_today.isEmpty
    }
    
    // MARK: - Time-Based Grouping

    private var groupedTasks: (anytime: [TaskDTO], morning: [TaskDTO], afternoon: [TaskDTO], evening: [TaskDTO]) {
        guard let data = todayData else { return ([], [], [], []) }
        var anytime: [TaskDTO] = [], morning: [TaskDTO] = []
        var afternoon: [TaskDTO] = [], evening: [TaskDTO] = []
        let calendar = Calendar.current
        for task in data.due_today {
            guard let dueDate = task.dueDate else { anytime.append(task); continue }
            let hour = calendar.component(.hour, from: dueDate)
            let minute = calendar.component(.minute, from: dueDate)
            if hour == 0 && minute == 0 { anytime.append(task) }
            else if hour < 12 { morning.append(task) }
            else if hour < 17 { afternoon.append(task) }
            else { evening.append(task) }
        }
        return (anytime, morning, afternoon, evening)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if let error = error {
                    errorView(error)
                } else if let data = todayData {
                    contentView(data)
                } else {
                    emptyView
                }
            }
            .navigationTitle("Today")
            .refreshable {
                await loadToday()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingQuickAdd = true
                    } label: {
                        Image(systemName: DS.Icon.plus)
                    }
                }
            }
            .sheet(isPresented: $showingQuickAdd) {
                QuickAddTaskView(onTaskCreated: {
                    await loadToday()
                })
            }
            .sheet(item: $selectedTask) { task in
                TaskDetailView(
                    task: task,
                    listName: task.list_name ?? "Unknown",
                    onComplete: {
                        await toggleComplete(task)
                        selectedTask = nil
                    },
                    onDelete: {
                        await deleteTask(task)
                        selectedTask = nil
                    },
                    onUpdate: {
                        await loadToday()
                    },
                    taskService: state.taskService,
                    tagService: state.tagService,
                    listId: task.list_id
                )
            }
        }
        .task {
            await loadToday()
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            updateEscalationState()
        }
        .onAppear {
            updateEscalationState()
        }
    }
    
    private func updateEscalationState() {
        Task { @MainActor in
            isBlocking = ScreenTimeService.shared.isBlocking
            isInGracePeriod = EscalationService.shared.isInGracePeriod
            gracePeriodRemaining = EscalationService.shared.gracePeriodRemainingFormatted
        }
    }
    
    private func contentView(_ data: TodayResponse) -> some View {
        let grouped = groupedTasks
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

                if isAllComplete {
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
        if isBlocking {
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
        } else if isInGracePeriod {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: DS.Icon.timer)
                    .font(.title3)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Grace Period")
                        .font(.body.weight(.semibold))
                    Text("Apps will be blocked in \(gracePeriodRemaining ?? "...")")
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
                    .trim(from: 0, to: progress)
                    .stroke(
                        isAllComplete ? DS.Colors.success : DS.Colors.accent,
                        style: StrokeStyle(lineWidth: DS.Size.progressStroke, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)
                
                if isAllComplete {
                    Image(systemName: "checkmark")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(DS.Colors.success)
                } else {
                    Text("\(Int(progress * 100))%")
                        .font(.title2.weight(.bold))
                }
            }
            .frame(width: DS.Size.progressRing, height: DS.Size.progressRing)
            
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.md) {
                    miniStat(count: completedCount, total: totalTasks, label: "Done")
                    
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
                    onComplete: { await loadToday() },
                    onTap: { selectedTask = task }
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
                Task { await loadToday() }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Task Actions
    
    private func toggleComplete(_ task: TaskDTO) async {
        if task.isCompleted {
            do {
                _ = try await state.taskService.reopenTask(listId: task.list_id, taskId: task.id)
                await loadToday()
            } catch {
                Logger.error("Failed to reopen task", error: error, category: .api)
            }
        } else {
            await loadToday()
        }
    }
    
    private func deleteTask(_ task: TaskDTO) async {
        do {
            try await state.taskService.deleteTask(listId: task.list_id, taskId: task.id)
            await loadToday()
        } catch {
            Logger.error("Failed to delete task", error: error, category: .api)
        }
    }
    
    private func loadToday() async {
        isLoading = todayData == nil
        error = nil
        
        do {
            todayData = try await todayService.fetchToday()
            onOverdueCountChange?(todayData?.stats.overdue_count ?? 0)
            
            let totalDueToday = (todayData?.stats.due_today_count ?? 0) + (todayData?.stats.overdue_count ?? 0)
            NotificationService.shared.scheduleMorningBriefing(taskCount: totalDueToday)
        } catch {
            self.error = ErrorHandler.shared.handle(error, context: "Loading Today")
        }
        
        isLoading = false
    }
}
