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
    
    private var anytimeTasks: [TaskDTO] {
        guard let data = todayData else { return [] }
        return data.due_today.filter { task in
            guard let dueDate = task.dueDate else { return true }
            let hour = Calendar.current.component(.hour, from: dueDate)
            let minute = Calendar.current.component(.minute, from: dueDate)
            return hour == 0 && minute == 0
        }
    }
    
    private var morningTasks: [TaskDTO] {
        guard let data = todayData else { return [] }
        return data.due_today.filter { task in
            guard let dueDate = task.dueDate else { return false }
            let hour = Calendar.current.component(.hour, from: dueDate)
            let minute = Calendar.current.component(.minute, from: dueDate)
            return !(hour == 0 && minute == 0) && hour < 12
        }
    }
    
    private var afternoonTasks: [TaskDTO] {
        guard let data = todayData else { return [] }
        return data.due_today.filter { task in
            guard let dueDate = task.dueDate else { return false }
            let hour = Calendar.current.component(.hour, from: dueDate)
            return hour >= 12 && hour < 17
        }
    }
    
    private var eveningTasks: [TaskDTO] {
        guard let data = todayData else { return [] }
        return data.due_today.filter { task in
            guard let dueDate = task.dueDate else { return false }
            let hour = Calendar.current.component(.hour, from: dueDate)
            return hour >= 17
        }
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
                        Image(systemName: "plus")
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
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
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
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Escalation banner (grace period or blocking)
                escalationBanner
                
                // Progress circle and streak
                progressSection(data)
                
                // Overdue section (always at top)
                if !data.overdue.isEmpty {
                    taskSection(
                        title: "Overdue",
                        icon: "exclamationmark.triangle.fill",
                        iconColor: DesignSystem.Colors.error,
                        tasks: data.overdue
                    )
                }
                
                // Anytime section
                if !anytimeTasks.isEmpty {
                    taskSection(
                        title: "Anytime Today",
                        icon: "calendar",
                        iconColor: DesignSystem.Colors.primary,
                        tasks: anytimeTasks
                    )
                }
                
                // Morning section
                if !morningTasks.isEmpty {
                    taskSection(
                        title: "Morning",
                        icon: "sunrise.fill",
                        iconColor: .orange,
                        tasks: morningTasks
                    )
                }
                
                // Afternoon section
                if !afternoonTasks.isEmpty {
                    taskSection(
                        title: "Afternoon",
                        icon: "sun.max.fill",
                        iconColor: .yellow,
                        tasks: afternoonTasks
                    )
                }
                
                // Evening section
                if !eveningTasks.isEmpty {
                    taskSection(
                        title: "Evening",
                        icon: "moon.fill",
                        iconColor: .indigo,
                        tasks: eveningTasks
                    )
                }
                
                // Completed section
                if !data.completed_today.isEmpty {
                    taskSection(
                        title: "Completed",
                        icon: "checkmark.circle.fill",
                        iconColor: DesignSystem.Colors.success,
                        tasks: data.completed_today
                    )
                }
                
                // All clear message
                if isAllComplete {
                    allClearView
                } else if data.overdue.isEmpty && data.due_today.isEmpty && data.completed_today.isEmpty {
                    nothingDueView
                }
            }
            .padding(DesignSystem.Spacing.padding)
        }
    }
    
    // MARK: - Escalation Banner
    
    @ViewBuilder
    private var escalationBanner: some View {
        if isBlocking {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "lock.fill")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apps Blocked")
                        .font(DesignSystem.Typography.body.bold())
                    Text("Complete your overdue tasks to unlock")
                        .font(DesignSystem.Typography.caption1)
                }
                Spacer()
            }
            .foregroundColor(.white)
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.error)
            .cornerRadius(DesignSystem.CornerRadius.md)
        } else if isInGracePeriod {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "timer")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Grace Period")
                        .font(DesignSystem.Typography.body.bold())
                    Text("Apps will be blocked in \(gracePeriodRemaining ?? "...")")
                        .font(DesignSystem.Typography.caption1)
                }
                Spacer()
            }
            .foregroundColor(.black)
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.warning)
            .cornerRadius(DesignSystem.CornerRadius.md)
        }
    }
    
    private func progressSection(_ data: TodayResponse) -> some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            ZStack {
                Circle()
                    .stroke(
                        DesignSystem.Colors.secondaryBackground,
                        lineWidth: 12
                    )
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        isAllComplete ? DesignSystem.Colors.success : DesignSystem.Colors.primary,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)
                
                VStack(spacing: 2) {
                    if isAllComplete {
                        Image(systemName: "checkmark")
                            .font(.title2.bold())
                            .foregroundColor(DesignSystem.Colors.success)
                    } else {
                        Text("\(Int(progress * 100))%")
                            .font(DesignSystem.Typography.title2)
                            .fontWeight(.bold)
                    }
                }
            }
            .frame(width: 80, height: 80)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    miniStat(count: completedCount, total: totalTasks, label: "Done")
                    
                    if data.stats.overdue_count > 0 {
                        miniStat(count: data.stats.overdue_count, label: "Overdue", color: DesignSystem.Colors.error)
                    }
                }
                
                if let streak = data.streak {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Text("🔥")
                        if streak.current > 0 {
                            Text("\(streak.current) day streak")
                                .font(DesignSystem.Typography.subheadline)
                                .fontWeight(.medium)
                        } else {
                            Text("Complete all tasks to start a streak!")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.secondaryBackground)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
    
    private func miniStat(count: Int, total: Int? = nil, label: String, color: Color = DesignSystem.Colors.textPrimary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let total = total {
                Text("\(count)/\(total)")
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            } else {
                Text("\(count)")
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
            Text(label)
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }
    
    private func taskSection(title: String, icon: String, iconColor: Color, tasks: [TaskDTO]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(DesignSystem.Typography.title3)
                Text("(\(tasks.count))")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
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
    
    private var allClearView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.success)
            Text("All Clear!")
                .font(DesignSystem.Typography.title2)
            Text("You've completed all your tasks for today!")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(DesignSystem.Spacing.xl)
    }
    
    private var nothingDueView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "calendar")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.textSecondary)
            Text("Nothing Due Today")
                .font(DesignSystem.Typography.title2)
            Text("Enjoy your free day or plan ahead!")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .padding(DesignSystem.Spacing.xl)
    }
    
    private var emptyView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.textSecondary)
            Text("No tasks yet")
                .font(DesignSystem.Typography.title2)
            Text("Create a task to get started")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }
    
    private func errorView(_ error: FocusmateError) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.error)
            Text("Something went wrong")
                .font(DesignSystem.Typography.title2)
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
            // Completion is handled by TaskRow
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
