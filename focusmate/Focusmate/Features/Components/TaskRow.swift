import SwiftUI

struct TaskRow: View {
    let task: TaskDTO
    let onComplete: () async -> Void
    let onStar: () async -> Void
    let onTap: () -> Void
    let onNudge: () async -> Void
    let onSubtaskEdit: (SubtaskDTO) -> Void
    let onSubtaskChanged: () async -> Void
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
    private var isSharedTask: Bool { task.creator != nil }

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
        onSubtaskChanged: @escaping () async -> Void = {},
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
        self.onSubtaskChanged = onSubtaskChanged
        self.onAddSubtask = onAddSubtask
        self.showStar = showStar
        self.showNudge = showNudge
    }

    var body: some View {
        HStack(spacing: 0) {
            // List color indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(task.taskColor)
                .frame(width: 4)
                .padding(.vertical, DS.Spacing.sm)

            VStack(spacing: 0) {
                mainTaskRow

                // Subtasks section
                if task.hasSubtasks && isExpanded {
                    subtasksList
                } else if !task.hasSubtasks && canEdit {
                    Divider()
                        .padding(.horizontal, DS.Spacing.md)
                    addSubtaskButton
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(isOverdue ? DS.Colors.error.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .opacity(task.isCompleted ? 0.6 : 1.0)
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
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            completeButton
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                // Title row with priority
                titleRow

                // Metadata row - due date, subtasks, visibility
                metadataRow
            }
            .contentShape(Rectangle())
            .onTapGesture {
                HapticManager.selection()
                onTap()
            }

            Spacer(minLength: DS.Spacing.sm)

            // Right side - avatar, star, indicators
            rightSection
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
                            .frame(width: 22, height: 22)
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
        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 22, weight: .light))
            .foregroundStyle(checkboxColor)
    }

    private var checkboxColor: Color {
        if task.isCompleted {
            return DS.Colors.success
        } else if isOverdue {
            return DS.Colors.error
        } else {
            return Color(.tertiaryLabel)
        }
    }

    private var titleRow: some View {
        HStack(spacing: DS.Spacing.xs) {
            // Priority indicator
            if task.taskPriority == .urgent {
                Image(systemName: "flag.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Colors.error)
            }

            Text(task.title)
                .font(.system(size: 16, weight: task.isCompleted ? .regular : .medium))
                .strikethrough(task.isCompleted)
                .foregroundStyle(titleColor)
                .lineLimit(2)

            if !canEdit {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var titleColor: Color {
        if task.isCompleted {
            return .secondary
        } else if isOverdue {
            return DS.Colors.error
        } else {
            return .primary
        }
    }

    private var metadataRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Due date
            if let dueDate = task.dueDate {
                HStack(spacing: 4) {
                    Image(systemName: isOverdue ? "clock.badge.exclamationmark.fill" : "clock")
                        .font(.system(size: 11))
                    Text(formatDueDate(dueDate))
                        .font(.system(size: 12))
                }
                .foregroundStyle(isOverdue ? DS.Colors.error : .secondary)
            }

            // Subtasks count (if any) - tappable to expand
            if task.hasSubtasks {
                subtaskBadge
            }

            // Recurring
            if task.isRecurring || task.isRecurringInstance {
                Image(systemName: "repeat")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            // Tags
            if let tags = task.tags, !tags.isEmpty {
                tagsView(tags)
            }
        }
    }

    private var subtaskBadge: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
            HapticManager.selection()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "checklist")
                    .font(.system(size: 11))
                Text(task.subtaskProgress)
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(DS.Colors.accent)
        }
        .buttonStyle(.plain)
    }

    private func tagsView(_ tags: [TagDTO]) -> some View {
        HStack(spacing: 4) {
            // Show first tag with name
            if let firstTag = tags.first {
                HStack(spacing: 3) {
                    Circle()
                        .fill(firstTag.tagColor)
                        .frame(width: 6, height: 6)
                    Text(firstTag.name)
                        .font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
            }

            // Show additional tags as dots with count
            if tags.count > 1 {
                HStack(spacing: 2) {
                    ForEach(tags.dropFirst().prefix(2)) { tag in
                        Circle()
                            .fill(tag.tagColor)
                            .frame(width: 6, height: 6)
                    }
                    if tags.count > 3 {
                        Text("+\(tags.count - 3)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var rightSection: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Creator avatar for shared lists
            if isSharedTask, let creator = task.creator {
                Avatar(creator.name ?? creator.email, size: 24)
            }

            // Star (only show if starred or can edit)
            if task.isStarred {
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.yellow)
            } else if showStar && canEdit {
                Button {
                    HapticManager.selection()
                    Task { await onStar() }
                } label: {
                    Image(systemName: "star")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(.quaternaryLabel))
                }
                .buttonStyle(.plain)
            }

            // Nudge button for shared lists
            if canNudge {
                nudgeButton
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
                    .scaleEffect(0.6)
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "hand.point.right.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(DS.Colors.accent)
            }
        }
        .buttonStyle(.plain)
        .disabled(isNudging)
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
                                await onSubtaskChanged()
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
                                await onSubtaskChanged()
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
