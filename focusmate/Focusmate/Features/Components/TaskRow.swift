import SwiftUI

struct TaskRow: View {
    let task: TaskDTO
    let onComplete: () async -> Void
    let onStar: () async -> Void
    let onTap: () -> Void
    let onNudge: () async -> Void
    let onSubtaskComplete: (SubtaskDTO) async -> Void
    let onSubtaskDelete: (SubtaskDTO) async -> Void
    let onSubtaskEdit: (SubtaskDTO) -> Void
    let onAddSubtask: () -> Void
    let showStar: Bool
    let showNudge: Bool
    
    @EnvironmentObject var state: AppState
    @State private var showingReasonSheet = false
    @State private var isNudging = false
    @State private var isExpanded = false
    
    private var isOverdue: Bool {
        task.isActuallyOverdue
    }
    
    private var canEdit: Bool {
        task.can_edit ?? true
    }
    
    private var canDelete: Bool {
        task.can_delete ?? true
    }
    
    private var canNudge: Bool {
        showNudge && !task.isCompleted
    }
    
    init(
        task: TaskDTO,
        onComplete: @escaping () async -> Void,
        onStar: @escaping () async -> Void = {},
        onTap: @escaping () -> Void = {},
        onNudge: @escaping () async -> Void = {},
        onSubtaskComplete: @escaping (SubtaskDTO) async -> Void = { _ in },
        onSubtaskDelete: @escaping (SubtaskDTO) async -> Void = { _ in },
        onSubtaskEdit: @escaping (SubtaskDTO) -> Void = { _ in },
        onAddSubtask: @escaping () -> Void = {},
        showStar: Bool = true,
        showNudge: Bool = false
    ) {
        self.task = task
        self.onComplete = onComplete
        self.onStar = onStar
        self.onTap = onTap
        self.onNudge = onNudge
        self.onSubtaskComplete = onSubtaskComplete
        self.onSubtaskDelete = onSubtaskDelete
        self.onSubtaskEdit = onSubtaskEdit
        self.onAddSubtask = onAddSubtask
        self.showStar = showStar
        self.showNudge = showNudge
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main task row
            mainTaskRow
            
            // Subtasks (expanded)
            if isExpanded {
                subtasksList
            }
        }
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
            if isOverdue && !task.isCompleted {
                Task { @MainActor in
                    EscalationService.shared.taskBecameOverdue(task)
                }
            }
        }
    }
    
    // MARK: - Main Task Row
    
    private var mainTaskRow: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Complete button
            completeButton
            
            // Task content
            taskContent
            
            Spacer()
            
            // Right side indicators
            rightIndicators
        }
        .padding(DesignSystem.Spacing.md)
    }
    
    private var completeButton: some View {
        Group {
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
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(task.isCompleted ? DesignSystem.Colors.success : DesignSystem.Colors.textSecondary.opacity(0.5))
            }
        }
    }
    
    private var taskContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            // Title row
            titleRow
            
            // Note preview
            if let note = task.note, !note.isEmpty {
                Text(note)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineLimit(1)
            }
            
            // Tags row
            tagsRow
            
            // Due date, overdue info, and subtask indicator
            metadataRow
        }
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.selection()
            onTap()
        }
    }
    
    private var titleRow: some View {
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
            
            if !canEdit {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.textSecondary.opacity(0.6))
            }
        }
    }
    
    @ViewBuilder
    private var tagsRow: some View {
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
    }
    
    private var metadataRow: some View {
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
            
            // Subtask indicator - show if has subtasks OR can edit (to allow adding first subtask)
            if task.hasSubtasks || canEdit {
                subtaskIndicator
            }
        }
    }
    
    private var subtaskIndicator: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
            HapticManager.selection()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "checklist")
                    .font(.caption2)
                if task.hasSubtasks {
                    Text(task.subtaskProgress)
                        .font(.caption2)
                }
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundColor(task.hasSubtasks ? DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((task.hasSubtasks ? DesignSystem.Colors.primary : DesignSystem.Colors.textSecondary).opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    private var rightIndicators: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            if isOverdue && !task.isCompleted {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(DesignSystem.Colors.error)
                    .font(.subheadline)
            }
            
            if canNudge {
                nudgeButton
            }
            
            if showStar && canEdit {
                starButton
            }
        }
    }
    
    private var nudgeButton: some View {
        Button {
            HapticManager.selection()
            Task {
                isNudging = true
                await onNudge()
                isNudging = false
            }
        } label: {
            if isNudging {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                Image(systemName: "hand.point.right.fill")
                    .foregroundColor(.blue)
                    .font(.subheadline)
            }
        }
        .buttonStyle(.plain)
        .disabled(isNudging)
    }
    
    private var starButton: some View {
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
    
    // MARK: - Subtasks List
    
    private var subtasksList: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, DesignSystem.Spacing.md)
            
            VStack(spacing: 0) {
                if let subtasks = task.subtasks {
                    ForEach(subtasks) { subtask in
                        SubtaskRow(
                            subtask: subtask,
                            canEdit: canEdit,
                            onComplete: {
                                await onSubtaskComplete(subtask)
                            },
                            onDelete: {
                                await onSubtaskDelete(subtask)
                            },
                            onTap: {
                                onSubtaskEdit(subtask)
                            }
                        )
                        
                        if subtask.id != subtasks.last?.id {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
                
                // Add subtask button
                if canEdit {
                    Divider()
                        .padding(.leading, 52)
                    
                    Button {
                        HapticManager.selection()
                        onAddSubtask()
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 18))
                                .foregroundColor(DesignSystem.Colors.primary)
                            
                            Text("Add subtask")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(DesignSystem.Colors.primary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 36)
        }
        .background(DesignSystem.Colors.cardBackground.opacity(0.5))
    }
    
    // MARK: - Actions
    
    private func handleCompleteTap() {
        guard canEdit else { return }
        
        HapticManager.selection()
        
        if task.isCompleted {
            Task { await onComplete() }
        } else if isOverdue {
            showingReasonSheet = true
        } else {
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

// MARK: - Subtask Row

struct SubtaskRow: View {
    let subtask: SubtaskDTO
    let canEdit: Bool
    let onComplete: () async -> Void
    let onDelete: () async -> Void
    let onTap: () -> Void
    
    @State private var isCompleting = false
    
    init(
        subtask: SubtaskDTO,
        canEdit: Bool,
        onComplete: @escaping () async -> Void,
        onDelete: @escaping () async -> Void = {},
        onTap: @escaping () -> Void = {}
    ) {
        self.subtask = subtask
        self.canEdit = canEdit
        self.onComplete = onComplete
        self.onDelete = onDelete
        self.onTap = onTap
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Complete button
            Button {
                guard canEdit else { return }
                HapticManager.selection()
                Task {
                    isCompleting = true
                    await onComplete()
                    isCompleting = false
                }
            } label: {
                if isCompleting {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(subtask.isCompleted ? DesignSystem.Colors.success : DesignSystem.Colors.textSecondary)
                }
            }
            .buttonStyle(.plain)
            .disabled(!canEdit || isCompleting)
            
            // Title - tappable for edit
            Text(subtask.title)
                .font(DesignSystem.Typography.caption1)
                .strikethrough(subtask.isCompleted)
                .foregroundColor(subtask.isCompleted ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.textPrimary)
                .contentShape(Rectangle())
                .onTapGesture {
                    if canEdit {
                        HapticManager.selection()
                        onTap()
                    }
                }
            
            Spacer()
            
            // Delete button
            if canEdit {
                Button {
                    HapticManager.warning()
                    Task { await onDelete() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(DesignSystem.Colors.textSecondary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .opacity(subtask.isCompleted ? 0.7 : 1.0)
    }
}
