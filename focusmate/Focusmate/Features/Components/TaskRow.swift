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
    
    private var isOverdue: Bool { task.isActuallyOverdue }
    private var canEdit: Bool { task.can_edit ?? true }
    private var canDelete: Bool { task.can_delete ?? true }
    private var canNudge: Bool { showNudge && !task.isCompleted }
    
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
            mainTaskRow
            
            if isExpanded {
                subtasksList
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(DS.Radius.md)
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
        HStack(spacing: DS.Spacing.md) {
            completeButton
            taskContent
            Spacer()
            rightIndicators
        }
        .padding(DS.Spacing.md)
    }
    
    private var completeButton: some View {
        Group {
            if canEdit {
                Button {
                    handleCompleteTap()
                } label: {
                    checkboxIcon
                }
                .buttonStyle(.plain)
            } else {
                checkboxIcon
                    .opacity(0.5)
            }
        }
    }
    
    private var checkboxIcon: some View {
        Image(systemName: task.isCompleted ? DS.Icon.circleChecked : DS.Icon.circle)
            .font(.system(size: DS.Size.checkbox))
            .foregroundStyle(task.isCompleted ? DS.Colors.success : .secondary)
    }
    
    private var taskContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            titleRow
            
            if let note = task.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            tagsRow
            metadataRow
        }
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.selection()
            onTap()
        }
    }
    
    private var titleRow: some View {
        HStack(spacing: DS.Spacing.xs) {
            if let icon = task.taskPriority.icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(task.taskPriority.color)
            }
            
            Text(task.title)
                .font(task.isCompleted ? .body : .body.weight(.medium))
                .strikethrough(task.isCompleted)
                .foregroundStyle(titleColor)
            
            if !canEdit {
                Image(systemName: DS.Icon.lock)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
    
    private var titleColor: Color {
        if task.isCompleted {
            return Color(.secondaryLabel)
        } else if isOverdue {
            return DS.Colors.overdue
        } else {
            return Color(.label)
        }
    }
    
    @ViewBuilder
    private var tagsRow: some View {
        if let tags = task.tags, !tags.isEmpty {
            HStack(spacing: DS.Spacing.xs) {
                ForEach(tags.prefix(3)) { tag in
                    TagPill(tag: tag)
                }
                
                if tags.count > 3 {
                    Text("+\(tags.count - 3)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var metadataRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            if let dueDate = task.dueDate {
                Label(formatDueDate(dueDate), systemImage: DS.Icon.clock)
                    .font(.caption)
                    .foregroundStyle(isOverdue ? DS.Colors.overdue : .secondary)
            }
            
            if isOverdue, let minutes = task.minutes_overdue {
                Text("• \(formatOverdue(minutes))")
                    .font(.caption)
                    .foregroundStyle(DS.Colors.overdue)
            }
            
            if task.isRecurring || task.isRecurringInstance {
                Image(systemName: DS.Icon.recurring)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
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
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: DS.Icon.subtasks)
                    .font(.caption2)
                
                if task.hasSubtasks {
                    Text(task.subtaskProgress)
                        .font(.caption2)
                }
                
                Image(systemName: isExpanded ? DS.Icon.chevronUp : DS.Icon.chevronDown)
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(task.hasSubtasks ? DS.Colors.accent : .secondary)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background((task.hasSubtasks ? DS.Colors.accent : Color.secondary).opacity(0.1))
            .cornerRadius(DS.Radius.sm)
        }
        .buttonStyle(.plain)
    }
    
    private var rightIndicators: some View {
        HStack(spacing: DS.Spacing.sm) {
            if isOverdue && !task.isCompleted {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(DS.Colors.error)
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
                    .font(.subheadline)
                    .foregroundStyle(DS.Colors.accent)
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
            Image(systemName: task.isStarred ? DS.Icon.starFilled : DS.Icon.star)
                .font(.subheadline)
                .foregroundStyle(task.isStarred ? Color.yellow : Color(.tertiaryLabel))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Subtasks List
    
    private var subtasksList: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, DS.Spacing.md)
            
            VStack(spacing: 0) {
                if let subtasks = task.subtasks {
                    ForEach(subtasks) { subtask in
                        SubtaskRow(
                            subtask: subtask,
                            canEdit: canEdit,
                            onComplete: { await onSubtaskComplete(subtask) },
                            onDelete: { await onSubtaskDelete(subtask) },
                            onTap: { onSubtaskEdit(subtask) }
                        )
                        
                        if subtask.id != subtasks.last?.id {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
                
                if canEdit {
                    Divider()
                        .padding(.leading, 52)
                    
                    addSubtaskButton
                }
            }
            .padding(.leading, 36)
        }
        .background(Color(.tertiarySystemBackground))
    }
    
    private var addSubtaskButton: some View {
        Button {
            HapticManager.selection()
            onAddSubtask()
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "plus.circle")
                    .font(.system(size: DS.Size.iconMedium))
                
                Text("Add subtask")
                    .font(.caption)
                
                Spacer()
            }
            .foregroundStyle(DS.Colors.accent)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
        }
        .buttonStyle(.plain)
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
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        if task.isAnytime {
            if calendar.isDateInToday(date) { return "Today" }
            if calendar.isDateInTomorrow(date) { return "Tomorrow" }
            if calendar.isDateInYesterday(date) { return "Yesterday" }
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
            return "Today \(formatter.string(from: date))"
        }
        if calendar.isDateInTomorrow(date) {
            formatter.dateFormat = "h:mm a"
            return "Tomorrow \(formatter.string(from: date))"
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }
    
    private func formatOverdue(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m overdue" }
        if minutes < 1440 { return "\(minutes / 60)h overdue" }
        return "\(minutes / 1440)d overdue"
    }
}

// MARK: - Tag Pill

private struct TagPill: View {
    let tag: TagDTO
    
    var body: some View {
        HStack(spacing: DS.Spacing.xxs) {
            Circle()
                .fill(tag.tagColor)
                .frame(width: 6, height: 6)
            
            Text(tag.name)
                .font(.caption2)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xxs)
        .background(tag.tagColor.opacity(0.15))
        .cornerRadius(DS.Radius.sm)
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
        HStack(spacing: DS.Spacing.sm) {
            // Checkbox
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
                        .frame(width: DS.Size.checkboxSmall, height: DS.Size.checkboxSmall)
                } else {
                    Image(systemName: subtask.isCompleted ? DS.Icon.circleChecked : DS.Icon.circle)
                        .font(.system(size: DS.Size.checkboxSmall))
                        .foregroundStyle(subtask.isCompleted ? DS.Colors.success : .secondary)
                }
            }
            .buttonStyle(.plain)
            .disabled(!canEdit || isCompleting)
            
            // Title
            Text(subtask.title)
                .font(.caption)
                .strikethrough(subtask.isCompleted)
                .foregroundStyle(subtask.isCompleted ? .secondary : .primary)
                .contentShape(Rectangle())
                .onTapGesture {
                    if canEdit {
                        HapticManager.selection()
                        onTap()
                    }
                }
            
            Spacer()
            
            // Delete
            if canEdit {
                Button {
                    HapticManager.warning()
                    Task { await onDelete() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: DS.Size.iconSmall))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .opacity(subtask.isCompleted ? 0.7 : 1.0)
    }
}
