import SwiftUI

struct TaskRow: View {
    let task: TaskDTO
    let onComplete: () async -> Void
    let onStar: () async -> Void
    let onTap: () -> Void
    let onNudge: () async -> Void
    let onSubtaskEdit: (SubtaskDTO) -> Void
    let onAddSubtask: () -> Void
    let showStar: Bool
    let showNudge: Bool

    @EnvironmentObject var state: AppState
    @State private var showingReasonSheet = false
    @State private var isNudging = false
    @State private var isExpanded = false
    @State private var isCompleting = false
    @State private var completionError: FocusmateError?

    private var isOverdue: Bool { task.isActuallyOverdue }
    private var canEdit: Bool { task.can_edit ?? true }
    private var canDelete: Bool { task.can_delete ?? true }
    private var canNudge: Bool { showNudge && !task.isCompleted }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()
    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f
    }()

    init(
        task: TaskDTO,
        onComplete: @escaping () async -> Void,
        onStar: @escaping () async -> Void = {},
        onTap: @escaping () -> Void = {},
        onNudge: @escaping () async -> Void = {},
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
        .background(DS.Colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .shadow(color: DS.Shadow.md.color, radius: DS.Shadow.md.radius, y: DS.Shadow.md.y)
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
        .errorBanner($completionError)
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
                    if isCompleting {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        checkboxIcon
                    }
                }
                .buttonStyle(.plain)
                .disabled(isCompleting)
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
                    .font(DS.Typography.caption)
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
                    .font(DS.Typography.caption)
                    .foregroundStyle(task.taskPriority.color)
            }

            Text(task.title)
                .font(task.isCompleted ? DS.Typography.body : DS.Typography.bodyMedium)
                .strikethrough(task.isCompleted)
                .foregroundStyle(titleColor)

            if !canEdit {
                Image(systemName: DS.Icon.lock)
                    .font(DS.Typography.caption2)
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
                        .font(DS.Typography.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var metadataRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            if let dueDate = task.dueDate {
                Label(formatDueDate(dueDate), systemImage: DS.Icon.clock)
                    .font(DS.Typography.caption)
                    .foregroundStyle(isOverdue ? DS.Colors.overdue : .secondary)
            }

            if isOverdue, let minutes = task.minutes_overdue {
                Text("• \(formatOverdue(minutes))")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.overdue)
            }

            if task.isRecurring || task.isRecurringInstance {
                Image(systemName: DS.Icon.recurring)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(.secondary)
            }

            if task.hasSubtasks || canEdit {
                subtaskIndicator
            }
        }
    }

    private var subtaskIndicator: some View {
        Button {
            withAnimation(DS.Anim.quick) {
                isExpanded.toggle()
            }
            HapticManager.selection()
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: DS.Icon.subtasks)
                    .font(DS.Typography.caption2)

                if task.hasSubtasks {
                    Text(task.subtaskProgress)
                        .font(DS.Typography.caption2)
                }

                Image(systemName: isExpanded ? DS.Icon.chevronUp : DS.Icon.chevronDown)
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(task.hasSubtasks ? DS.Colors.accent : .secondary)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background((task.hasSubtasks ? DS.Colors.accent : Color.secondary).opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var rightIndicators: some View {
        HStack(spacing: DS.Spacing.sm) {
            if isOverdue && !task.isCompleted {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(DS.Typography.subheadline)
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
                    .font(DS.Typography.subheadline)
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
                .font(DS.Typography.subheadline)
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
                            onComplete: {
                                do {
                                    if subtask.isCompleted {
                                        _ = try await state.taskService.reopenSubtask(
                                            listId: task.list_id,
                                            parentTaskId: task.id,
                                            subtaskId: subtask.id
                                        )
                                    } else {
                                        _ = try await state.taskService.completeSubtask(
                                            listId: task.list_id,
                                            parentTaskId: task.id,
                                            subtaskId: subtask.id
                                        )
                                    }
                                    HapticManager.light()
                                } catch {
                                    Logger.error("Failed to toggle subtask: \(error)", category: .api)
                                    HapticManager.error()
                                }
                                await onComplete()
                            },
                            onDelete: {
                                do {
                                    try await state.taskService.deleteSubtask(
                                        listId: task.list_id,
                                        parentTaskId: task.id,
                                        subtaskId: subtask.id
                                    )
                                    HapticManager.medium()
                                } catch {
                                    Logger.error("Failed to delete subtask: \(error)", category: .api)
                                    HapticManager.error()
                                }
                                await onComplete()
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
                    .font(DS.Typography.caption)

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
            isCompleting = true
            Task {
                defer { isCompleting = false }
                await onComplete()
            }
        } else if isOverdue {
            showingReasonSheet = true
        } else {
            isCompleting = true
            Task {
                await completeTask(reason: nil)
            }
        }
    }

    private func completeTask(reason: String?) async {
        defer { isCompleting = false }
        do {
            _ = try await state.taskService.completeTask(
                listId: task.list_id,
                taskId: task.id,
                reason: reason
            )

            await MainActor.run {
                EscalationService.shared.taskCompleted(task.id)
            }

            HapticManager.success()
            await onComplete()
        } catch {
            Logger.error("Failed to complete task", error: error, category: .api)
            HapticManager.error()
            completionError = ErrorHandler.shared.handle(error, context: "Completing task")
        }
    }

    // MARK: - Formatting

    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current

        if task.isAnytime {
            if calendar.isDateInToday(date) { return "Today" }
            if calendar.isDateInTomorrow(date) { return "Tomorrow" }
            if calendar.isDateInYesterday(date) { return "Yesterday" }
            return Self.dateFormatter.string(from: date)
        }

        if calendar.isDateInToday(date) {
            return "Today \(Self.timeFormatter.string(from: date))"
        }
        if calendar.isDateInTomorrow(date) {
            return "Tomorrow \(Self.timeFormatter.string(from: date))"
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        return Self.dateTimeFormatter.string(from: date)
    }

    private func formatOverdue(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m overdue" }
        if minutes < 1440 { return "\(minutes / 60)h overdue" }
        return "\(minutes / 1440)d overdue"
    }
}

// MARK: - Tag Pill (larger, capsule shape)

private struct TagPill: View {
    let tag: TagDTO

    var body: some View {
        HStack(spacing: DS.Spacing.xxs) {
            Circle()
                .fill(tag.tagColor)
                .frame(width: 6, height: 6)

            Text(tag.name)
                .font(DS.Typography.caption2)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(tag.tagColor.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Subtask Row
// Uses onTapGesture instead of Button to avoid List edit mode intercepting taps

struct SubtaskRow: View {
    let subtask: SubtaskDTO
    let canEdit: Bool
    let onComplete: () async -> Void
    let onDelete: () async -> Void
    let onTap: () -> Void

    @State private var isCompleting = false
    @State private var isDeleting = false

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
            // Checkbox — onTapGesture to bypass List edit mode button interception
            Group {
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
            .frame(width: DS.Size.checkboxSmall, height: DS.Size.checkboxSmall)
            .contentShape(Rectangle())
            .onTapGesture {
                guard canEdit, !isCompleting else { return }
                HapticManager.selection()
                Task {
                    isCompleting = true
                    await onComplete()
                    isCompleting = false
                }
            }

            // Title
            Text(subtask.title)
                .font(DS.Typography.caption)
                .strikethrough(subtask.isCompleted)
                .foregroundStyle(subtask.isCompleted ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard canEdit else { return }
                    HapticManager.selection()
                    onTap()
                }

            // Delete
            if canEdit {
                Group {
                    if isDeleting {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 28, height: 28)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: DS.Size.iconSmall))
                            .foregroundStyle(Color(.tertiaryLabel))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                }
                .onTapGesture {
                    guard !isDeleting else { return }
                    HapticManager.warning()
                    Task {
                        isDeleting = true
                        await onDelete()
                        isDeleting = false
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .opacity(subtask.isCompleted ? 0.7 : 1.0)
    }
}
