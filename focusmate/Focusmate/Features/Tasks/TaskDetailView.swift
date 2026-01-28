import SwiftUI

struct TaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm: TaskDetailViewModel

    init(
        task: TaskDTO,
        listName: String,
        onComplete: @escaping () async -> Void,
        onDelete: @escaping () async -> Void,
        onUpdate: @escaping () async -> Void,
        taskService: TaskService,
        tagService: TagService,
        listId: Int
    ) {
        _vm = State(initialValue: TaskDetailViewModel(
            task: task,
            listName: listName,
            listId: listId,
            taskService: taskService,
            tagService: tagService,
            onComplete: onComplete,
            onDelete: onDelete,
            onUpdate: onUpdate
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    headerSection

                    Divider()

                    detailsSection

                    if let tags = vm.task.tags, !tags.isEmpty {
                        tagsSection(tags)
                    }

                    if let note = vm.task.note, !note.isEmpty {
                        notesSection(note)
                    }

                    Spacer()

                    actionsSection
                }
                .padding(DS.Spacing.md)
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        vm.showingEditTask = true
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
            .sheet(isPresented: $vm.showingEditTask) {
                EditTaskView(
                    listId: vm.listId,
                    task: vm.task,
                    taskService: vm.taskService,
                    tagService: vm.tagService,
                    onSave: {
                        Task {
                            await vm.onUpdate()
                            dismiss()
                        }
                    }
                )
            }
            .sheet(isPresented: $vm.showingReasonSheet) {
                OverdueReasonSheet(task: vm.task) { reason in
                    Task {
                        await vm.onComplete()
                        vm.showingReasonSheet = false
                        dismiss()
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
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Button {
                handleComplete()
            } label: {
                Image(systemName: vm.task.isCompleted ? DS.Icon.circleChecked : DS.Icon.circle)
                    .font(.system(size: 28))
                    .foregroundStyle(vm.task.isCompleted ? DS.Colors.success : .secondary)
            }

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
            }
        }
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

    // MARK: - Details Section

    private var detailsSection: some View {
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

    // MARK: - Tags Section

    private func tagsSection(_ tags: [TagDTO]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Tags")
                .font(.caption)
                .foregroundStyle(.secondary)

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
    }

    // MARK: - Notes Section

    private func notesSection(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Notes")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(note)
                .font(.body)
                .foregroundStyle(.primary)
                .padding(DS.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: DS.Spacing.sm) {
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

            Button(role: .destructive) {
                vm.showingDeleteConfirmation = true
            } label: {
                Label("Delete Task", systemImage: DS.Icon.trash)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(IntentiaSecondaryButtonStyle())
        }
    }

    // MARK: - Actions

    private func handleComplete() {
        if vm.task.isCompleted {
            Task {
                await vm.onComplete()
                dismiss()
            }
        } else if vm.isOverdue {
            vm.showingReasonSheet = true
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
