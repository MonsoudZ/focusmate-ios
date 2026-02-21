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

  private var isSharedTask: Bool {
    self.task.creator != nil
  }

  var body: some View {
    HStack(spacing: DS.Spacing.sm) {
      // Creator avatar for shared lists
      if self.isSharedTask, let creator = task.creator {
        Avatar(creator.displayName, size: 24)
      }

      // Star (only show if starred or can edit)
      self.starButton

      // Nudge button for shared lists
      if self.canNudge {
        self.nudgeButton
      }
    }
  }

  // MARK: - Subviews

  @ViewBuilder
  private var starButton: some View {
    if self.task.isStarred {
      Image(systemName: "star.fill")
        .scaledFont(size: 14, relativeTo: .footnote)
        .foregroundStyle(.yellow)
        .accessibilityLabel("Starred")
    } else if self.showStar, self.canEdit {
      Button {
        HapticManager.selection()
        Task { await self.onStar() }
      } label: {
        Image(systemName: "star")
          .scaledFont(size: 14, relativeTo: .footnote)
          .foregroundStyle(Color(.quaternaryLabel))
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Star task")
      .accessibilityHint("Double tap to mark as important")
    }
  }

  private var nudgeButton: some View {
    Button {
      HapticManager.selection()
      self.onNudge()
    } label: {
      if self.isNudging {
        ProgressView()
          .scaleEffect(0.6)
          .frame(width: 24, height: 24)
      } else {
        Image(systemName: "hand.point.right.fill")
          .scaledFont(size: 14, relativeTo: .footnote)
          .foregroundStyle(DS.Colors.accent)
      }
    }
    .buttonStyle(.plain)
    .disabled(self.isNudging)
    .accessibilityLabel(self.isNudging ? "Sending nudge" : "Nudge")
    .accessibilityHint("Double tap to send a reminder to the task owner")
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
      if self.canEdit {
        Button(action: self.onTap) {
          self.checkboxContent
        }
        .buttonStyle(.plain)
        .disabled(self.isCompleting)
        .accessibilityLabel(self.task.isCompleted ? "Mark incomplete" : "Mark complete")
        .accessibilityHint(self.task.isCompleted ? "Double tap to reopen task" : "Double tap to complete task")
      } else {
        self.checkboxIcon
          .opacity(0.5)
      }
    }
  }

  @ViewBuilder
  private var checkboxContent: some View {
    if self.isCompleting {
      ProgressView()
        .scaleEffect(0.7)
        .frame(width: 22, height: 22)
    } else {
      self.checkboxIcon
    }
  }

  private var checkboxIcon: some View {
    Image(systemName: self.task.isCompleted ? "checkmark.circle.fill" : "circle")
      .scaledFont(size: 22, weight: .light, relativeTo: .title2)
      .foregroundStyle(self.checkboxColor)
      .accessibilityLabel(self.task.isCompleted ? "Completed" : "Not completed")
  }

  private var checkboxColor: Color {
    if self.task.isCompleted {
      return DS.Colors.success
    } else if self.isOverdue {
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
          .scaledFont(size: 12, relativeTo: .caption)
          .foregroundStyle(self.task.taskPriority.color)
      }

      Text(self.task.title)
        .scaledFont(size: 16, weight: self.task.isCompleted ? .regular : .medium, relativeTo: .callout)
        .strikethrough(self.task.isCompleted)
        .foregroundStyle(self.titleColor)
        .lineLimit(2)

      if !self.canEdit {
        Image(systemName: "lock.fill")
          .scaledFont(size: 10, relativeTo: .caption2)
          .foregroundStyle(.tertiary)
      }
    }
  }

  private var titleColor: Color {
    if self.task.isCompleted {
      return .secondary
    } else if self.isOverdue {
      return DS.Colors.error
    } else {
      return .primary
    }
  }
}
