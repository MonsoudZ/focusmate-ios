import SwiftUI

struct TaskDetailView: View {
    let task: TaskDTO
    let listName: String
    let onComplete: () async -> Void
    let onDelete: () async -> Void
    let onUpdate: () async -> Void
    let taskService: TaskService
    let tagService: TagService
    let listId: Int
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditTask = false
    @State private var showingDeleteConfirmation = false
    @State private var showingReasonSheet = false
    
    private var isOverdue: Bool {
        task.isActuallyOverdue
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    headerSection
                    
                    Divider()
                    
                    detailsSection
                    
                    if let tags = task.tags, !tags.isEmpty {
                        tagsSection(tags)
                    }
                    
                    if let note = task.note, !note.isEmpty {
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
                        showingEditTask = true
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
            .sheet(isPresented: $showingEditTask) {
                EditTaskView(
                    listId: listId,
                    task: task,
                    taskService: taskService,
                    tagService: tagService,
                    onSave: {
                        Task {
                            await onUpdate()
                            dismiss()
                        }
                    }
                )
            }
            .sheet(isPresented: $showingReasonSheet) {
                OverdueReasonSheet(task: task) { reason in
                    Task {
                        await onComplete()
                        showingReasonSheet = false
                        dismiss()
                    }
                }
            }
            .alert("Delete Task", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        await onDelete()
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
                Image(systemName: task.isCompleted ? DS.Icon.circleChecked : DS.Icon.circle)
                    .font(.system(size: 28))
                    .foregroundStyle(task.isCompleted ? DS.Colors.success : .secondary)
            }
            
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                // Priority badge
                if task.taskPriority != .none {
                    priorityBadge
                }
                
                // Title
                Text(task.title)
                    .font(.title3.weight(.semibold))
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(isOverdue ? DS.Colors.error : .primary)
                
                // Overdue badge
                if isOverdue {
                    overdueBadge
                }
            }
            
            Spacer()
            
            if task.isStarred {
                Image(systemName: DS.Icon.starFilled)
                    .foregroundStyle(.yellow)
            }
        }
    }
    
    private var priorityBadge: some View {
        HStack(spacing: DS.Spacing.xs) {
            if let icon = task.taskPriority.icon {
                Image(systemName: icon)
            }
            Text(task.taskPriority.label)
        }
        .font(.caption)
        .foregroundStyle(task.taskPriority.color)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(task.taskPriority.color.opacity(0.15))
        .cornerRadius(DS.Radius.sm)
    }
    
    private var overdueBadge: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: DS.Icon.overdue)
            Text("Overdue")
            if let minutes = task.minutes_overdue {
                Text("• \(formatOverdue(minutes))")
            }
        }
        .font(.caption)
        .foregroundStyle(DS.Colors.error)
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if let dueDate = task.dueDate {
                detailRow(
                    icon: DS.Icon.calendar,
                    title: "Due",
                    value: formatDueDate(dueDate),
                    valueColor: isOverdue ? DS.Colors.error : nil
                )
            }
            
            detailRow(
                icon: "list.bullet",
                title: "List",
                value: listName
            )
            
            if let recurrence = task.recurrenceDescription {
                detailRow(
                    icon: DS.Icon.recurring,
                    title: "Repeats",
                    value: recurrence
                )
            }
            
            if task.isCompleted, let completedAt = task.completed_at {
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
                    .cornerRadius(DS.Radius.md)
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
                .cornerRadius(DS.Radius.md)
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            Button {
                handleComplete()
            } label: {
                Label(
                    task.isCompleted ? "Mark Incomplete" : "Mark Complete",
                    systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(task.isCompleted ? DS.Colors.warning : DS.Colors.success)
            
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label("Delete Task", systemImage: DS.Icon.trash)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Actions
    
    private func handleComplete() {
        if task.isCompleted {
            Task {
                await onComplete()
                dismiss()
            }
        } else if isOverdue {
            showingReasonSheet = true
        } else {
            Task {
                await onComplete()
                dismiss()
            }
        }
    }
    
    // MARK: - Formatting
    
    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        if task.isAnytime {
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
