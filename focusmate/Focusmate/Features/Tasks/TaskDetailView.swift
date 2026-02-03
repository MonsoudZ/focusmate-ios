import SwiftUI

struct TaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.router) private var router
    @State private var vm: TaskDetailViewModel
    @State private var showingAddSubtask = false
    @State private var editingSubtask: SubtaskDTO?

    init(
        task: TaskDTO,
        listName: String,
        onComplete: @escaping () async -> Void,
        onDelete: @escaping () async -> Void,
        onUpdate: @escaping () async -> Void,
        taskService: TaskService,
        tagService: TagService,
        subtaskManager: SubtaskManager,
        listId: Int
    ) {
        _vm = State(initialValue: TaskDetailViewModel(
            task: task,
            listName: listName,
            listId: listId,
            taskService: taskService,
            tagService: tagService,
            subtaskManager: subtaskManager,
            onComplete: onComplete,
            onDelete: onDelete,
            onUpdate: onUpdate
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.md) {
                    // Header Card
                    headerCard

                    // Info Card (progress + creator)
                    if vm.hasSubtasks || vm.isSharedTask {
                        infoCard
                    }

                    // Details Card
                    detailsCard

                    // Subtasks Card
                    if vm.hasSubtasks || vm.canEdit {
                        subtasksCard
                    }

                    // Tags Card
                    if let tags = vm.task.tags, !tags.isEmpty {
                        tagsCard(tags)
                    }

                    // Notes Card
                    if let note = vm.task.note, !note.isEmpty {
                        notesCard(note)
                    }

                    // Missed Reason Card
                    if let missedReason = vm.task.missed_reason, !missedReason.isEmpty {
                        missedReasonCard(missedReason)
                    }

                    // Actions
                    actionsSection
                }
                .padding(DS.Spacing.md)
            }
            .surfaceBackground()
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if vm.canEdit {
                        Button("Edit") {
                            presentEditTask()
                        }
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: DS.Icon.close)
                    }
                }
            }
            .alert("Delete Task", isPresented: $vm.showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        await vm.onDelete()
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to delete this task?")
            }
            .sheet(isPresented: $showingAddSubtask) {
                AddSubtaskSheet(parentTask: vm.task) { title in
                    await vm.createSubtask(title: title)
                }
            }
            .sheet(item: $editingSubtask) { subtask in
                EditSubtaskSheet(subtask: subtask) { newTitle in
                    await vm.updateSubtask(subtask, title: newTitle)
                }
            }
            .overlay(alignment: .top) {
                toastOverlay
            }
            .floatingErrorBanner($vm.error)
        }
    }

    // MARK: - Toast Overlay

    @ViewBuilder
    private var toastOverlay: some View {
        if vm.showNudgeSent {
            toastView(icon: "hand.point.right.fill", message: "Nudge sent!")
        } else if vm.showCopied {
            toastView(icon: "doc.on.doc.fill", message: "Link copied!")
        }
    }

    private func toastView(icon: String, message: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
            Text(message)
                .font(DS.Typography.bodyMedium)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Colors.success)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .padding(.top, DS.Spacing.md)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(duration: 0.3), value: vm.showNudgeSent || vm.showCopied)
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Main header row
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Button {
                    handleComplete()
                } label: {
                    Image(systemName: vm.task.isCompleted ? DS.Icon.circleChecked : DS.Icon.circle)
                        .font(.system(size: 28))
                        .foregroundStyle(vm.task.isCompleted ? DS.Colors.success : .secondary)
                }
                .disabled(!vm.canEdit)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    // Priority badge
                    if vm.task.taskPriority != .none {
                        priorityBadge
                    }

                    // Title
                    Text(vm.task.title)
                        .font(DS.Typography.title3)
                        .strikethrough(vm.task.isCompleted)
                        .foregroundStyle(vm.isOverdue ? DS.Colors.error : .primary)

                    // Overdue badge
                    if vm.isOverdue {
                        overdueBadge
                    }
                }

                Spacer()

                if vm.task.isStarred {
                    Image(systemName: DS.Icon.starFilled)
                        .foregroundStyle(.yellow)
                        .font(.system(size: 20))
                }
            }

            // Quick actions row
            quickActionsRow
        }
        .card()
    }

    private var priorityBadge: some View {
        HStack(spacing: DS.Spacing.xs) {
            if let icon = vm.task.taskPriority.icon {
                Image(systemName: icon)
            }
            Text(vm.task.taskPriority.label)
        }
        .font(.caption)
        .foregroundStyle(vm.task.taskPriority.color)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(vm.task.taskPriority.color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
    }

    private var overdueBadge: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: DS.Icon.overdue)
            Text("Overdue")
            if let minutes = vm.task.minutes_overdue {
                Text("• \(formatOverdue(minutes))")
            }
        }
        .font(.caption)
        .foregroundStyle(DS.Colors.error)
    }

    private var quickActionsRow: some View {
        HStack(spacing: DS.Spacing.lg) {
            // Star/Unstar
            if vm.canEdit {
                Button {
                    Task { await vm.toggleStar() }
                } label: {
                    VStack(spacing: DS.Spacing.xs) {
                        Image(systemName: vm.task.isStarred ? DS.Icon.starFilled : DS.Icon.star)
                            .font(.system(size: 20))
                            .foregroundStyle(vm.task.isStarred ? .yellow : DS.Colors.accent)
                        Text(vm.task.isStarred ? "Unstar" : "Star")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }

            // Hide/Show (for shared tasks only)
            if vm.canHide {
                Button {
                    Task { await vm.toggleHidden() }
                } label: {
                    VStack(spacing: DS.Spacing.xs) {
                        Image(systemName: vm.task.isHidden ? "eye" : "eye.slash")
                            .font(.system(size: 20))
                            .foregroundStyle(vm.task.isHidden ? DS.Colors.success : DS.Colors.accent)
                        Text(vm.task.isHidden ? "Show" : "Hide")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }

            // Share
            ShareLink(item: URL(string: "focusmate://task/\(vm.task.id)")!) {
                VStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20))
                        .foregroundStyle(DS.Colors.accent)
                    Text("Share")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            // Copy Link
            Button {
                vm.copyTaskLink()
            } label: {
                VStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 20))
                        .foregroundStyle(DS.Colors.accent)
                    Text("Copy")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            // Nudge (for shared tasks only, when not completed)
            if vm.isSharedTask && !vm.task.isCompleted {
                Button {
                    Task { await vm.nudgeTask() }
                } label: {
                    VStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "hand.point.right.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(DS.Colors.accent)
                        Text("Nudge")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.top, DS.Spacing.sm)
    }

    // MARK: - Info Card

    private var infoCard: some View {
        HStack(spacing: DS.Spacing.lg) {
            // Progress ring for subtasks
            if vm.hasSubtasks {
                VStack(spacing: DS.Spacing.xs) {
                    miniProgressRing
                    Text(vm.subtaskProgressText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Creator info for shared tasks
            if vm.isSharedTask, let creator = vm.task.creator {
                HStack(spacing: DS.Spacing.sm) {
                    Avatar(creator.name ?? creator.email, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Created by")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(creator.name ?? creator.email)
                            .font(.subheadline.weight(.medium))
                    }
                }
            }

            Spacer()
        }
        .card()
    }

    private var miniProgressRing: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 4)

            Circle()
                .trim(from: 0, to: vm.subtaskProgress)
                .stroke(
                    vm.subtaskProgress >= 1.0
                        ? DS.Colors.success
                        : DS.Colors.accent,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.3), value: vm.subtaskProgress)

            if vm.subtaskProgress >= 1.0 {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DS.Colors.success)
            }
        }
        .frame(width: 32, height: 32)
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if let dueDate = vm.task.dueDate {
                detailRow(
                    icon: DS.Icon.calendar,
                    title: "Due",
                    value: formatDueDate(dueDate),
                    valueColor: vm.isOverdue ? DS.Colors.error : nil
                )
            }

            detailRow(
                icon: "list.bullet",
                title: "List",
                value: vm.listName
            )

            if let recurrence = vm.task.recurrenceDescription {
                detailRow(
                    icon: DS.Icon.recurring,
                    title: "Repeats",
                    value: recurrence
                )
            }

            if vm.task.isCompleted, let completedAt = vm.task.completed_at {
                if let date = ISO8601DateFormatter().date(from: completedAt) {
                    detailRow(
                        icon: DS.Icon.circleChecked,
                        title: "Completed",
                        value: formatDueDate(date),
                        valueColor: DS.Colors.success
                    )
                }
            }
        }
        .card()
    }

    private func detailRow(icon: String, title: String, value: String, valueColor: Color? = nil) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title)
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.body)
                .foregroundStyle(valueColor ?? Color(.label))
        }
    }

    // MARK: - Subtasks Card

    private var subtasksCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    vm.isSubtasksExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "checklist")
                        .foregroundStyle(.secondary)
                    Text("Subtasks")
                        .font(.headline)
                    if vm.hasSubtasks {
                        Text("(\(vm.subtaskProgressText))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: vm.isSubtasksExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(DS.Spacing.md)
            }
            .buttonStyle(.plain)

            if vm.isSubtasksExpanded {
                Divider()
                    .padding(.horizontal, DS.Spacing.md)

                // Subtask list
                if vm.hasSubtasks {
                    VStack(spacing: 0) {
                        ForEach(vm.subtasks) { subtask in
                            SubtaskRow(
                                subtask: subtask,
                                canEdit: vm.canEdit,
                                onComplete: {
                                    await vm.toggleSubtaskComplete(subtask)
                                },
                                onDelete: {
                                    await vm.deleteSubtask(subtask)
                                },
                                onTap: {
                                    editingSubtask = subtask
                                }
                            )

                            if subtask.id != vm.subtasks.last?.id {
                                Divider()
                                    .padding(.leading, 52)
                            }
                        }
                    }
                }

                // Add subtask button
                if vm.canEdit {
                    if vm.hasSubtasks {
                        Divider()
                            .padding(.leading, 52)
                    }

                    Button {
                        showingAddSubtask = true
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
            }
        }
        .background(DS.Colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .shadow(color: DS.Shadow.md.color, radius: DS.Shadow.md.radius, y: DS.Shadow.md.y)
    }

    // MARK: - Tags Card

    private func tagsCard(_ tags: [TagDTO]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Image(systemName: "tag")
                    .foregroundStyle(.secondary)
                Text("Tags")
                    .font(.headline)
                Spacer()
            }

            FlowLayout(spacing: DS.Spacing.sm) {
                ForEach(tags) { tag in
                    HStack(spacing: DS.Spacing.xs) {
                        Circle()
                            .fill(tag.tagColor)
                            .frame(width: 8, height: 8)
                        Text(tag.name)
                            .font(.caption)
                    }
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(tag.tagColor.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
        }
        .card()
    }

    // MARK: - Notes Card

    private func notesCard(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundStyle(.secondary)
                Text("Notes")
                    .font(.headline)
                Spacer()
            }

            Text(note)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .card()
    }

    // MARK: - Missed Reason Card

    private func missedReasonCard(_ reason: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Image(systemName: "exclamationmark.bubble")
                    .foregroundStyle(DS.Colors.warning)
                Text("Completion Note")
                    .font(.headline)
                Spacer()
            }

            Text(reason)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.warning.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            if vm.canEdit {
                Button {
                    handleComplete()
                } label: {
                    Label(
                        vm.task.isCompleted ? "Mark Incomplete" : "Mark Complete",
                        systemImage: vm.task.isCompleted ? "arrow.uturn.backward" : "checkmark"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(IntentiaPrimaryButtonStyle())
                .tint(vm.task.isCompleted ? DS.Colors.warning : DS.Colors.success)
            }

            if vm.task.can_delete ?? true {
                Button(role: .destructive) {
                    vm.showingDeleteConfirmation = true
                } label: {
                    Label("Delete Task", systemImage: DS.Icon.trash)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(IntentiaSecondaryButtonStyle())
            }
        }
        .padding(.top, DS.Spacing.md)
    }

    // MARK: - Sheet Presentation

    private func presentEditTask() {
        router.sheetCallbacks.onTaskSaved = {
            Task {
                await vm.onUpdate()
                dismiss()
            }
        }
        router.present(.editTask(vm.task, listId: vm.listId))
    }

    private func presentOverdueReason() {
        router.sheetCallbacks.onOverdueReasonSubmitted = { _ in
            Task {
                await vm.onComplete()
                router.dismissSheet()
                dismiss()
            }
        }
        router.present(.overdueReason(vm.task))
    }

    // MARK: - Actions

    private func handleComplete() {
        if vm.task.isCompleted {
            Task {
                await vm.onComplete()
                dismiss()
            }
        } else if vm.isOverdue {
            presentOverdueReason()
        } else {
            Task {
                await vm.onComplete()
                dismiss()
            }
        }
    }

    // MARK: - Formatting

    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()

        if vm.task.isAnytime {
            if calendar.isDateInToday(date) { return "Today" }
            if calendar.isDateInTomorrow(date) { return "Tomorrow" }
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        }

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "'Today at' h:mm a"
        } else if calendar.isDateInTomorrow(date) {
            formatter.dateFormat = "'Tomorrow at' h:mm a"
        } else {
            formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        }

        return formatter.string(from: date)
    }

    private func formatOverdue(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        if minutes < 1440 { return "\(minutes / 60)h" }
        return "\(minutes / 1440)d"
    }
}
