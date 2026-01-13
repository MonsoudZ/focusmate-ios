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
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    // Header with completion status
                    headerSection
                    
                    Divider()
                    
                    // Details
                    detailsSection
                    
                    // Tags
                    if let tags = task.tags, !tags.isEmpty {
                        tagsSection(tags)
                    }
                    
                    // Notes
                    if let note = task.note, !note.isEmpty {
                        notesSection(note)
                    }
                    
                    Spacer()
                    
                    // Actions
                    actionsSection
                }
                .padding(DesignSystem.Spacing.md)
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingEditTask = true
                    } label: {
                        Text("Edit")
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
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
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            // Completion circle
            Button {
                handleComplete()
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28))
                    .foregroundColor(task.isCompleted ? DesignSystem.Colors.success : DesignSystem.Colors.textSecondary)
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                // Priority badge
                if task.taskPriority != .none {
                    HStack(spacing: 4) {
                        if let icon = task.taskPriority.icon {
                            Image(systemName: icon)
                        }
                        Text(task.taskPriority.label)
                    }
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(task.taskPriority.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(task.taskPriority.color.opacity(0.15))
                    .cornerRadius(6)
                }
                
                // Title
                Text(task.title)
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(isOverdue ? DesignSystem.Colors.error : DesignSystem.Colors.textPrimary)
                
                // Overdue badge
                if isOverdue {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Overdue")
                        if let minutes = task.minutes_overdue {
                            Text("• \(formatOverdue(minutes))")
                        }
                    }
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(DesignSystem.Colors.error)
                }
            }
            
            Spacer()
            
            // Star
            if task.isStarred {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
            }
        }
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Due date
            if let dueDate = task.dueDate {
                detailRow(
                    icon: "calendar",
                    title: "Due",
                    value: formatDueDate(dueDate),
                    valueColor: isOverdue ? DesignSystem.Colors.error : DesignSystem.Colors.textPrimary
                )
            }
            
            // List
            detailRow(
                icon: "list.bullet",
                title: "List",
                value: listName
            )
            
            // Recurring info
            if let recurrence = task.recurrenceDescription {
                detailRow(
                    icon: "repeat",
                    title: "Repeats",
                    value: recurrence
                )
            }
            
            // Completed date
            if task.isCompleted, let completedAt = task.completed_at {
                if let date = ISO8601DateFormatter().date(from: completedAt) {
                    detailRow(
                        icon: "checkmark.circle",
                        title: "Completed",
                        value: formatDueDate(date),
                        valueColor: DesignSystem.Colors.success
                    )
                }
            }
        }
    }
    
    private func detailRow(icon: String, title: String, value: String, valueColor: Color = DesignSystem.Colors.textPrimary) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .frame(width: 24)
            
            Text(title)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(DesignSystem.Typography.body)
                .foregroundColor(valueColor)
        }
    }
    
    // MARK: - Tags Section
    
    private func tagsSection(_ tags: [TagDTO]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Tags")
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            FlowLayout(spacing: 8) {
                ForEach(tags) { tag in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(tag.tagColor)
                            .frame(width: 8, height: 8)
                        Text(tag.name)
                            .font(DesignSystem.Typography.caption1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(tag.tagColor.opacity(0.15))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - Notes Section
    
    private func notesSection(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Notes")
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            Text(note)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .padding(DesignSystem.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignSystem.Colors.secondaryBackground)
                .cornerRadius(DesignSystem.CornerRadius.md)
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Complete/Uncomplete button
            Button {
                handleComplete()
            } label: {
                HStack {
                    Image(systemName: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
                    Text(task.isCompleted ? "Mark Incomplete" : "Mark Complete")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(task.isCompleted ? .orange : DesignSystem.Colors.success)
            
            // Delete button
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Task")
                }
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
            if calendar.isDateInToday(date) {
                return "Today"
            } else if calendar.isDateInTomorrow(date) {
                return "Tomorrow"
            } else {
                formatter.dateFormat = "MMM d, yyyy"
                return formatter.string(from: date)
            }
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
        if minutes < 60 {
            return "\(minutes)m"
        } else if minutes < 1440 {
            return "\(minutes / 60)h"
        } else {
            return "\(minutes / 1440)d"
        }
    }
}
