import SwiftUI

struct TodayView: View {
    @EnvironmentObject var state: AppState
    @State private var todayData: TodayResponse?
    @State private var isLoading = true
    @State private var error: FocusmateError?
    @State private var showingQuickAdd = false
    
    var onOverdueCountChange: ((Int) -> Void)? = nil
    
    private var todayService: TodayService {
        TodayService(api: state.auth.api)
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
        }
        .task {
            await loadToday()
        }
    }
    
    private func contentView(_ data: TodayResponse) -> some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Stats summary
                statsCard(data.stats)
                
                // Overdue section
                if !data.overdue.isEmpty {
                    taskSection(
                        title: "Overdue",
                        icon: "exclamationmark.triangle.fill",
                        iconColor: DesignSystem.Colors.error,
                        tasks: data.overdue
                    )
                }
                
                // Due today section
                if !data.due_today.isEmpty {
                    taskSection(
                        title: "Due Today",
                        icon: "clock.fill",
                        iconColor: DesignSystem.Colors.warning,
                        tasks: data.due_today
                    )
                }
                
                // Completed section
                if !data.completed_today.isEmpty {
                    taskSection(
                        title: "Completed Today",
                        icon: "checkmark.circle.fill",
                        iconColor: DesignSystem.Colors.success,
                        tasks: data.completed_today
                    )
                }
                
                // All clear message
                if data.overdue.isEmpty && data.due_today.isEmpty {
                    allClearView
                }
            }
            .padding(DesignSystem.Spacing.padding)
        }
    }
    
    private func statsCard(_ stats: TodayStats) -> some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            statItem(count: stats.overdue_count, label: "Overdue", color: DesignSystem.Colors.error)
            statItem(count: stats.due_today_count, label: "Due", color: DesignSystem.Colors.warning)
            statItem(count: stats.completed_today_count, label: "Done", color: DesignSystem.Colors.success)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.secondaryBackground)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
    
    private func statItem(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Text("\(count)")
                .font(DesignSystem.Typography.title1)
                .foregroundColor(color)
            Text(label)
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
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
                TodayTaskRow(task: task, onComplete: {
                    await loadToday()
                })
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
            Text("No tasks due today. Enjoy your day!")
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
    
    private func loadToday() async {
        isLoading = todayData == nil
        error = nil
        
        do {
            todayData = try await todayService.fetchToday()
            onOverdueCountChange?(todayData?.stats.overdue_count ?? 0)
            
            // Schedule morning briefing for tomorrow
            let totalDueToday = (todayData?.stats.due_today_count ?? 0) + (todayData?.stats.overdue_count ?? 0)
            NotificationService.shared.scheduleMorningBriefing(taskCount: totalDueToday)
        } catch {
            self.error = ErrorHandler.shared.handle(error, context: "Loading Today")
        }
        
        isLoading = false
    }
}
