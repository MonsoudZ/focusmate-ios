import SwiftUI

struct TaskRowView: View {
    let task: TaskDTO
    let onToggleComplete: () -> Void
    let onToggleStar: () -> Void

    private var isOverdue: Bool {
        task.isActuallyOverdue
    }
    
    private var dueDateText: String? {
        guard let dueDate = task.dueDate else { return nil }
        
        // Don't show time for anytime tasks
        if task.isAnytime {
            let calendar = Calendar.current
            if calendar.isDateInToday(dueDate) {
                return "Today"
            } else if calendar.isDateInTomorrow(dueDate) {
                return "Tomorrow"
            } else if calendar.isDateInYesterday(dueDate) {
                return "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return formatter.string(from: dueDate)
            }
        }
        
        let calendar = Calendar.current
        
        if calendar.isDateInToday(dueDate) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Today \(formatter.string(from: dueDate))"
        } else if calendar.isDateInTomorrow(dueDate) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Tomorrow \(formatter.string(from: dueDate))"
        } else if calendar.isDateInYesterday(dueDate) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, h:mm a"
            return formatter.string(from: dueDate)
        }
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Button {
                HapticManager.success()
                onToggleComplete()
            } label: {
                Image(systemName: task.isCompleted ? DesignSystem.Icons.taskCompleted : DesignSystem.Icons.task)
                    .foregroundColor(task.isCompleted ? DesignSystem.Colors.success : task.taskColor)
                    .font(.title2)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
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
                        .foregroundColor(isOverdue ? DesignSystem.Colors.overdue : DesignSystem.Colors.textPrimary)

                    if isOverdue {
                        Image(systemName: DesignSystem.Icons.taskOverdue)
                            .foregroundColor(DesignSystem.Colors.overdue)
                            .font(DesignSystem.Typography.caption1)
                    }
                }

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

                if let dueDateText {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(dueDateText)
                            .font(DesignSystem.Typography.caption1)
                    }
                    .foregroundColor(isOverdue ? DesignSystem.Colors.overdue : DesignSystem.Colors.textSecondary)
                }
            }

            Spacer()
            
            Button {
                HapticManager.selection()
                onToggleStar()
            } label: {
                Image(systemName: task.isStarred ? "star.fill" : "star")
                    .foregroundColor(task.isStarred ? .yellow : .gray.opacity(0.4))
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
            
            if task.color != nil {
                Circle()
                    .fill(task.taskColor)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .opacity(task.isCompleted ? 0.6 : 1.0)
        .taskAccessibility(
            title: task.title,
            isCompleted: task.isCompleted,
            dueDate: task.dueDate,
            isOverdue: isOverdue
        )
    }
}
