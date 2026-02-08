import SwiftUI

/// Right-side action buttons for TaskRow: avatar, star, nudge
struct TaskRowActions: View {
    let task: TaskDTO
    let showStar: Bool
    let canEdit: Bool
    let canNudge: Bool
    let isNudging: Bool
    let onStar: () async -> Void
    let onNudge: () -> Void

    private var isSharedTask: Bool { task.creator != nil }

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Creator avatar for shared lists
            if isSharedTask, let creator = task.creator {
                Avatar(creator.name ?? creator.email, size: 24)
            }

            // Star (only show if starred or can edit)
            starButton

            // Nudge button for shared lists
            if canNudge {
                nudgeButton
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var starButton: some View {
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
    }

    private var nudgeButton: some View {
        Button {
            HapticManager.selection()
            onNudge()
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
}

/// Completion checkbox button for TaskRow
struct TaskRowCheckbox: View {
    let task: TaskDTO
    let canEdit: Bool
    let isCompleting: Bool
    let isOverdue: Bool
    let onTap: () -> Void

    var body: some View {
        Group {
            if canEdit {
                Button(action: onTap) {
                    checkboxContent
                }
                .buttonStyle(.plain)
                .disabled(isCompleting)
            } else {
                checkboxIcon
                    .opacity(0.5)
            }
        }
    }

    @ViewBuilder
    private var checkboxContent: some View {
        if isCompleting {
            ProgressView()
                .scaleEffect(0.7)
                .frame(width: 22, height: 22)
        } else {
            checkboxIcon
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
}

/// Title row with priority indicator
struct TaskRowTitle: View {
    let task: TaskDTO
    let canEdit: Bool
    let isOverdue: Bool

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            // Priority indicator
            if let icon = task.taskPriority.icon {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(task.taskPriority.color)
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
}
