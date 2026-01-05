import SwiftUI

struct TaskRowView: View {
    let task: TaskDTO
    let onToggleComplete: () -> Void

    private var isOverdue: Bool {
        guard let dueDate = task.dueDate, !task.isCompleted else { return false }
        return dueDate < Date()
    }
    
    private var dueDateText: String? {
        guard let dueDate = task.dueDate else { return nil }
        
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
                HStack {
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
