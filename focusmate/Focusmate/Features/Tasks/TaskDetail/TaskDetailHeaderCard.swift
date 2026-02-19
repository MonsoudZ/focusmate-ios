import SwiftUI

/// Header card showing task title, completion status, priority, and starred state
struct TaskDetailHeaderCard: View {
    let task: TaskDTO
    let isOverdue: Bool
    let canEdit: Bool
    let onComplete: () -> Void
    let onToggleStar: () async -> Void
    let onToggleHidden: () async -> Void
    let onReschedule: () -> Void
    let onCopyLink: () -> Void
    let onNudge: () async -> Void
    let canHide: Bool
    let canNudge: Bool
    var isNudgeOnCooldown: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Main header row
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Button {
                    onComplete()
                } label: {
                    Image(systemName: task.isCompleted ? DS.Icon.circleChecked : DS.Icon.circle)
                        .font(.system(size: 28))
                        .foregroundStyle(task.isCompleted ? DS.Colors.success : .secondary)
                }
                .disabled(!canEdit)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    // Priority badge
                    if task.taskPriority != .none {
                        TaskDetailPriorityBadge(priority: task.taskPriority)
                    }

                    // Title
                    Text(task.title)
                        .font(DS.Typography.title3)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(isOverdue ? DS.Colors.error : .primary)

                    // Overdue badge
                    if isOverdue {
                        TaskDetailOverdueBadge(minutesOverdue: task.minutes_overdue)
                    }
                }

                Spacer()

                if task.isStarred {
                    Image(systemName: DS.Icon.starFilled)
                        .foregroundStyle(.yellow)
                        .font(.system(size: 20))
                }
            }

            // Quick actions row
            TaskDetailQuickActions(
                task: task,
                canEdit: canEdit,
                canHide: canHide,
                canNudge: canNudge,
                isNudgeOnCooldown: isNudgeOnCooldown,
                onToggleStar: onToggleStar,
                onToggleHidden: onToggleHidden,
                onReschedule: onReschedule,
                onCopyLink: onCopyLink,
                onNudge: onNudge
            )
        }
        .card()
    }
}

// MARK: - Priority Badge

struct TaskDetailPriorityBadge: View {
    let priority: TaskPriority

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            if let icon = priority.icon {
                Image(systemName: icon)
            }
            Text(priority.label)
        }
        .font(.caption)
        .foregroundStyle(priority.color)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(priority.color.opacity(DS.Opacity.tintBackground))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
    }
}

// MARK: - Overdue Badge

struct TaskDetailOverdueBadge: View {
    let minutesOverdue: Int?

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: DS.Icon.overdue)
            Text("Overdue")
            if let minutes = minutesOverdue {
                Text("• \(formatOverdue(minutes))")
            }
        }
        .font(.caption)
        .foregroundStyle(DS.Colors.error)
    }

    private func formatOverdue(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        if minutes < 1440 { return "\(minutes / 60)h" }
        return "\(minutes / 1440)d"
    }
}
