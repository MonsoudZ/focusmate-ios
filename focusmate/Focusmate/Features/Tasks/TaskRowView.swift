import SwiftUI

struct TaskRowView: View {
    let task: TaskDTO
    let onToggleComplete: () -> Void

    private var isOverdue: Bool {
        guard let dueDate = task.dueDate, !task.isCompleted else { return false }
        return dueDate < Date()
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Button {
                onToggleComplete()
            } label: {
                Image(systemName: task.isCompleted ? DesignSystem.Icons.taskCompleted : DesignSystem.Icons.task)
                    .foregroundColor(task.isCompleted ? DesignSystem.Colors.success : DesignSystem.Colors.textSecondary)
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

                if let dueDate = task.dueDate {
                    Text(dueDate, style: .date)
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(isOverdue ? DesignSystem.Colors.overdue : DesignSystem.Colors.textSecondary)
                }
            }

            Spacer()
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
