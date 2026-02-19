import SwiftUI

/// Quick action buttons for task detail (star, hide, reschedule, share, copy, nudge)
struct TaskDetailQuickActions: View {
  let task: TaskDTO
  let canEdit: Bool
  let canHide: Bool
  let canNudge: Bool
  let isNudgeOnCooldown: Bool
  let onToggleStar: () async -> Void
  let onToggleHidden: () async -> Void
  let onReschedule: () -> Void
  let onCopyLink: () -> Void
  let onNudge: () async -> Void

  var body: some View {
    HStack(spacing: DS.Spacing.lg) {
      // Star/Unstar
      if self.canEdit, !self.task.isCompleted {
        QuickActionButton(
          icon: self.task.isStarred ? DS.Icon.starFilled : DS.Icon.star,
          label: self.task.isStarred ? "Unstar" : "Star",
          iconColor: self.task.isStarred ? .yellow : DS.Colors.accent
        ) {
          Task { await self.onToggleStar() }
        }
      }

      // Hide/Show (for shared tasks only)
      if self.canHide {
        QuickActionButton(
          icon: self.task.isHidden ? "eye" : "eye.slash",
          label: self.task.isHidden ? "Show" : "Hide",
          iconColor: self.task.isHidden ? DS.Colors.success : DS.Colors.accent
        ) {
          Task { await self.onToggleHidden() }
        }
      }

      // Reschedule (for tasks with due date that can be edited)
      if self.canEdit, self.task.dueDate != nil, !self.task.isCompleted {
        QuickActionButton(
          icon: "calendar.badge.clock",
          label: "Reschedule",
          iconColor: DS.Colors.accent
        ) {
          self.onReschedule()
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
        self.onCopyLink()
      }

      // Nudge (for shared lists with 2+ members, when not completed)
      if self.canNudge {
        QuickActionButton(
          icon: self.isNudgeOnCooldown ? "checkmark.circle" : "hand.point.right.fill",
          label: self.isNudgeOnCooldown ? "Nudged" : "Nudge",
          iconColor: self.isNudgeOnCooldown ? .secondary : DS.Colors.accent
        ) {
          Task { await self.onNudge() }
        }
        .disabled(self.isNudgeOnCooldown)
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
    Button(action: self.action) {
      VStack(spacing: DS.Spacing.xs) {
        Image(systemName: self.icon)
          .font(.system(size: 20))
          .foregroundStyle(self.iconColor)
        Text(self.label)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .buttonStyle(.plain)
  }
}
