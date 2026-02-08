import SwiftUI

/// Displays task metadata: due date, subtask count, recurring indicator, hidden status, and tags
struct TaskRowMetadata: View {
    let task: TaskDTO
    let isOverdue: Bool
    let isExpanded: Bool
    let onExpandToggle: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Due date
            if let dueDate = task.dueDate {
                dueDateView(dueDate)
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

            // Hidden indicator
            if task.isHidden {
                hiddenIndicator
            }

            // Tags
            if let tags = task.tags, !tags.isEmpty {
                TaskRowTags(tags: tags)
            }
        }
    }

    // MARK: - Subviews

    private func dueDateView(_ dueDate: Date) -> some View {
        HStack(spacing: 4) {
            Image(systemName: isOverdue ? "clock.badge.exclamationmark.fill" : "clock")
                .font(.system(size: 11))
            Text(TaskRowDateFormatter.formatDueDate(dueDate, isAnytime: task.isAnytime))
                .font(.system(size: 12))
        }
        .foregroundStyle(isOverdue ? DS.Colors.error : .secondary)
    }

    private var subtaskBadge: some View {
        Button {
            onExpandToggle()
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
        .accessibilityLabel("Subtasks \(task.subtaskProgress)")
        .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand")
    }

    private var hiddenIndicator: some View {
        HStack(spacing: 3) {
            Image(systemName: "eye.slash")
                .font(.system(size: 11))
            Text("Hidden")
                .font(.system(size: 12))
        }
        .foregroundStyle(.secondary)
    }
}

/// Displays task tags as pills
struct TaskRowTags: View {
    let tags: [TagDTO]

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(tags.prefix(2)) { tag in
                Text(tag.name)
                    .font(DS.Typography.caption2.weight(.medium))
                    .foregroundStyle(tag.tagColor)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(tag.tagColor.opacity(0.15))
                    .clipShape(Capsule())
            }

            if tags.count > 2 {
                Text("+\(tags.count - 2)")
                    .font(DS.Typography.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Capsule())
            }
        }
    }
}

/// Date formatting utilities for TaskRow
enum TaskRowDateFormatter {
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

    static func formatDueDate(_ date: Date, isAnytime: Bool) -> String {
        let calendar = Calendar.current

        if isAnytime {
            if calendar.isDateInToday(date) { return "Today" }
            if calendar.isDateInTomorrow(date) { return "Tomorrow" }
            if calendar.isDateInYesterday(date) { return "Yesterday" }
            return dateFormatter.string(from: date)
        }

        if calendar.isDateInToday(date) {
            return "Today \(timeFormatter.string(from: date))"
        }
        if calendar.isDateInTomorrow(date) {
            return "Tomorrow \(timeFormatter.string(from: date))"
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        return dateTimeFormatter.string(from: date)
    }

    static func formatOverdue(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m overdue" }
        if minutes < 1440 { return "\(minutes / 60)h overdue" }
        return "\(minutes / 1440)d overdue"
    }
}
