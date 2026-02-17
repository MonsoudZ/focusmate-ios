import SwiftUI

/// Quick action buttons for task detail (star, hide, reschedule, share, copy, nudge)
struct TaskDetailQuickActions: View {
    let task: TaskDTO
    let canEdit: Bool
    let canHide: Bool
    let canNudge: Bool
    let onToggleStar: () async -> Void
    let onToggleHidden: () async -> Void
    let onReschedule: () -> Void
    let onCopyLink: () -> Void
    let onNudge: () async -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.lg) {
            // Star/Unstar
            if canEdit && !task.isCompleted {
                QuickActionButton(
                    icon: task.isStarred ? DS.Icon.starFilled : DS.Icon.star,
                    label: task.isStarred ? "Unstar" : "Star",
                    iconColor: task.isStarred ? .yellow : DS.Colors.accent
                ) {
                    Task { await onToggleStar() }
                }
            }

            // Hide/Show (for shared tasks only)
            if canHide {
                QuickActionButton(
                    icon: task.isHidden ? "eye" : "eye.slash",
                    label: task.isHidden ? "Show" : "Hide",
                    iconColor: task.isHidden ? DS.Colors.success : DS.Colors.accent
                ) {
                    Task { await onToggleHidden() }
                }
            }

            // Reschedule (for tasks with due date that can be edited)
            if canEdit && task.dueDate != nil && !task.isCompleted {
                QuickActionButton(
                    icon: "calendar.badge.clock",
                    label: "Reschedule",
                    iconColor: DS.Colors.accent
                ) {
                    onReschedule()
                }
            }

            // Share
            if let shareURL = URL(string: "intentia://task/\(task.id)") {
                ShareLink(item: shareURL) {
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
            }

            // Copy Link
            QuickActionButton(
                icon: "doc.on.doc",
                label: "Copy",
                iconColor: DS.Colors.accent
            ) {
                onCopyLink()
            }

            // Nudge (for shared lists with 2+ members, when not completed)
            if canNudge {
                QuickActionButton(
                    icon: "hand.point.right.fill",
                    label: "Nudge",
                    iconColor: DS.Colors.accent
                ) {
                    Task { await onNudge() }
                }
            }

            Spacer()
        }
        .padding(.top, DS.Spacing.sm)
    }
}

// MARK: - Quick Action Button

private struct QuickActionButton: View {
    let icon: String
    let label: String
    let iconColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(iconColor)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
