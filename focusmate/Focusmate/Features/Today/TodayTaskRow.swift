import SwiftUI

struct TodayTaskRow: View {
    let task: TaskDTO
    let onComplete: () async -> Void
    
    @EnvironmentObject var state: AppState
    @State private var showingReasonSheet = false
    @State private var selectedReason: String?
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Complete button
            Button {
                if task.needsReason {
                    showingReasonSheet = true
                } else {
                    Task { await completeTask(reason: nil) }
                }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(task.isCompleted ? DesignSystem.Colors.success : DesignSystem.Colors.textSecondary)
            }
            
            // Task info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(task.title)
                    .font(DesignSystem.Typography.body)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.textPrimary)
                
                HStack(spacing: DesignSystem.Spacing.sm) {
                    if let dueDate = task.dueDate {
                        Label(formatTime(dueDate), systemImage: "clock")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(task.isOverdue ? DesignSystem.Colors.error : DesignSystem.Colors.textSecondary)
                    }
                    
                    if task.isOverdue, let minutes = task.minutes_overdue {
                        Text(formatOverdue(minutes))
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(DesignSystem.Colors.error)
                    }
                }
            }
            
            Spacer()
            
            // Overdue indicator
            if task.needsReason {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(DesignSystem.Colors.error)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.md)
        .sheet(isPresented: $showingReasonSheet) {
            OverdueReasonSheet(task: task) { reason in
                Task {
                    await completeTask(reason: reason)
                    showingReasonSheet = false
                }
            }
        }
    }
    
    private func completeTask(reason: String?) async {
        do {
            let endpoint = API.Lists.taskAction(String(task.list_id), String(task.id), "complete")
            var body: [String: String]? = nil
            if let reason = reason {
                body = ["missed_reason": reason]
            }
            let _: TaskDTO = try await state.auth.api.request("PATCH", endpoint, body: body)
            await onComplete()
        } catch {
            Logger.error("Failed to complete task", error: error, category: .api)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatOverdue(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m overdue"
        } else if minutes < 1440 {
            return "\(minutes / 60)h overdue"
        } else {
            return "\(minutes / 1440)d overdue"
        }
    }
}
