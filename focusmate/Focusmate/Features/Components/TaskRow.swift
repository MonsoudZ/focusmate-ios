import SwiftUI

struct TaskRow: View {
    let task: TaskDTO
    let onComplete: () async -> Void
    let onStar: (() async -> Void)?
    let onTap: (() -> Void)?
    let onNudge: (() async -> Void)?
    
    @EnvironmentObject var state: AppState
    @State private var showingReasonSheet = false
    @State private var isNudging = false
    
    private var isOverdue: Bool {
        task.isActuallyOverdue
    }
    
    private var canEdit: Bool {
        task.can_edit ?? true
    }
    
    private var canDelete: Bool {
        task.can_delete ?? true
    }
    
    /// Whether this is a shared task that user can nudge about
    private var canNudge: Bool {
        // Can nudge if: shared task, not completed, and we can't edit it (we're a viewer)
        // OR it's assigned to someone else
        onNudge != nil && !task.isCompleted
    }
    
    init(
        task: TaskDTO,
        onComplete: @escaping () async -> Void,
        onStar: (() async -> Void)? = nil,
        onTap: (() -> Void)? = nil,
        onNudge: (() async -> Void)? = nil
    ) {
        self.task = task
        self.onComplete = onComplete
        self.onStar = onStar
        self.onTap = onTap
        self.onNudge = onNudge
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Complete button - only if can edit
            if canEdit {
                Button {
                    handleCompleteTap()
                } label: {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundColor(task.isCompleted ? DesignSystem.Colors.success : DesignSystem.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            } else {
                // Read-only indicator for viewers
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(task.isCompleted ? DesignSystem.Colors.success : DesignSystem.Colors.textSecondary.opacity(0.5))
            }
            
            // Task content - tappable area
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                // Title row with priority and permission indicator
                HStack(spacing: 4) {
                    if let icon = task.taskPriority.icon {
                        Image(systemName: icon)
                            .foregroundColor(task.taskPriority.color)
                            .font(.caption)
                    }
                    
                    Text(task.title)
                        .font(DesignSystem.Typography.body)
                        .fontWeight(task.isCompleted ? .regular : .medium)
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? DesignSystem.Colors.textSecondary : (isOverdue ? DesignSystem.Colors.error : DesignSystem.Colors.textPrimary))
                    
                    // Read-only indicator
                    if !canEdit {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.textSecondary.opacity(0.6))
                    }
                }
                
                // Note preview
                if let note = task.note, !note.isEmpty {
                    Text(note)
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                }
                
                // Tags row
                if let tags = task.tags, !tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(tags.prefix(3)) { tag in
                            HStack(spacing: 2) {
                                Circle()
                                    .fill(tag.tagColor)
                                    .frame(width: 6, height: 6)
                                Text(tag.name)
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(tag.tagColor.opacity(0.15))
                            .cornerRadius(8)
                        }
                        
                        if tags.count > 3 {
                            Text("+\(tags.count - 3)")
                                .font(.caption2)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
                
                // Due date and overdue info
                HStack(spacing: DesignSystem.Spacing.sm) {
                    if let dueDate = task.dueDate {
                        Label(formatDueDate(dueDate), systemImage: "clock")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(isOverdue ? DesignSystem.Colors.error : DesignSystem.Colors.textSecondary)
                    }
                    
                    if isOverdue, let minutes = task.minutes_overdue {
                        Text("• \(formatOverdue(minutes))")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(DesignSystem.Colors.error)
                    }
                    
                    if task.isRecurring || task.isRecurringInstance {
                        Image(systemName: "repeat")
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if let onTap {
                    HapticManager.selection()
                    onTap()
                }
            }
            
            Spacer()
            
            // Right side indicators
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Overdue indicator
                if isOverdue && !task.isCompleted {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.error)
                        .font(.subheadline)
                }
                
                // Nudge button - for shared tasks
                if canNudge {
                    Button {
                        HapticManager.selection()
                        Task {
                            isNudging = true
                            await onNudge?()
                            isNudging = false
                        }
                    } label: {
                        if isNudging {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "hand.point.right.fill")
                                .foregroundColor(DesignSystem.Colors.accent)
                                .font(.subheadline)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isNudging)
                }
                
                // Star button - only if can edit
                if let onStar, canEdit {
                    Button {
                        HapticManager.selection()
                        Task { await onStar() }
                    } label: {
                        Image(systemName: task.isStarred ? "star.fill" : "star")
                            .foregroundColor(task.isStarred ? .yellow : .gray.opacity(0.4))
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.md)
        .opacity(task.isCompleted ? 0.7 : 1.0)
        .sheet(isPresented: $showingReasonSheet) {
            OverdueReasonSheet(task: task) { reason in
                Task {
                    await completeTask(reason: reason)
                    showingReasonSheet = false
                }
            }
        }
        .onAppear {
            // Register overdue task with escalation service
            if isOverdue && !task.isCompleted {
                Task { @MainActor in
                    EscalationService.shared.taskBecameOverdue(task)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleCompleteTap() {
        guard canEdit else { return }
        
        HapticManager.selection()
        
        if task.isCompleted {
            // Uncomplete - delegate to parent
            Task { await onComplete() }
        } else if isOverdue {
            // Show reason sheet
            showingReasonSheet = true
        } else {
            // Complete normally
            Task { await completeTask(reason: nil) }
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
            
            // Notify escalation service
            await MainActor.run {
                EscalationService.shared.taskCompleted(task.id)
            }
            
            HapticManager.success()
            await onComplete()
        } catch {
            Logger.error("Failed to complete task", error: error, category: .api)
            HapticManager.error()
        }
    }
    
    // MARK: - Formatting
    
    private func formatDueDate(_ date: Date) -> String {
        if task.isAnytime {
            let calendar = Calendar.current
            if calendar.isDateInToday(date) {
                return "Today"
            } else if calendar.isDateInTomorrow(date) {
                return "Tomorrow"
            } else if calendar.isDateInYesterday(date) {
                return "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return formatter.string(from: date)
            }
        }
        
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
            return "Today \(formatter.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            formatter.dateFormat = "h:mm a"
            return "Tomorrow \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
            return formatter.string(from: date)
        }
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
