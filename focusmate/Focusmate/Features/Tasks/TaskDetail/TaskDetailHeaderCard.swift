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
          self.onComplete()
        } label: {
          Image(systemName: self.task.isCompleted ? DS.Icon.circleChecked : DS.Icon.circle)
            .scaledFont(size: 28, relativeTo: .title)
            .foregroundStyle(self.task.isCompleted ? DS.Colors.success : .secondary)
        }
        .disabled(!self.canEdit)

        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
          // Priority badge
          if self.task.taskPriority != .none {
            TaskDetailPriorityBadge(priority: self.task.taskPriority)
          }

          // Title
          Text(self.task.title)
            .font(DS.Typography.title3)
            .strikethrough(self.task.isCompleted)
            .foregroundStyle(self.isOverdue ? DS.Colors.error : .primary)

          // Overdue badge
          if self.isOverdue {
            TaskDetailOverdueBadge(minutesOverdue: self.task.minutes_overdue)
          }
        }

        Spacer()

        if self.task.isStarred {
          Image(systemName: DS.Icon.starFilled)
            .foregroundStyle(.yellow)
            .scaledFont(size: 20, relativeTo: .title3)
        }
      }

      // Quick actions row
      TaskDetailQuickActions(
        task: self.task,
        canEdit: self.canEdit,
        canHide: self.canHide,
        canNudge: self.canNudge,
        isNudgeOnCooldown: self.isNudgeOnCooldown,
        onToggleStar: self.onToggleStar,
        onToggleHidden: self.onToggleHidden,
        onReschedule: self.onReschedule,
        onCopyLink: self.onCopyLink,
        onNudge: self.onNudge
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
      Text(self.priority.label)
    }
    .font(.caption)
    .foregroundStyle(self.priority.color)
    .padding(.horizontal, DS.Spacing.sm)
    .padding(.vertical, DS.Spacing.xs)
    .background(self.priority.color.opacity(DS.Opacity.tintBackground))
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
        Text("• \(self.formatOverdue(minutes))")
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
