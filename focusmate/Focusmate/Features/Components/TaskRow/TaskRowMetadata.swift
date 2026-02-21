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
        self.dueDateView(dueDate)
      }

      // Subtasks count (if any) - tappable to expand
      if self.task.hasSubtasks {
        self.subtaskBadge
      }

      // Recurring
      if self.task.isRecurring || self.task.isRecurringInstance {
        Image(systemName: "repeat")
          .scaledFont(size: 11, relativeTo: .caption2)
          .foregroundStyle(.secondary)
      }

      // Hidden indicator
      if self.task.isHidden {
        self.hiddenIndicator
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
      Image(systemName: self.isOverdue ? "clock.badge.exclamationmark.fill" : "clock")
        .scaledFont(size: 11, relativeTo: .caption2)
      Text(DueDateFormatter.compact(dueDate, isAnytime: self.task.isAnytime))
        .scaledFont(size: 12, relativeTo: .caption)
    }
    .foregroundStyle(self.isOverdue ? DS.Colors.error : .secondary)
  }

  private var subtaskBadge: some View {
    Button {
      self.onExpandToggle()
    } label: {
      HStack(spacing: 3) {
        Image(systemName: "checklist")
          .scaledFont(size: 11, relativeTo: .caption2)
        Text(self.task.subtaskProgress)
          .scaledFont(size: 12, weight: .medium, relativeTo: .caption)
        Image(systemName: self.isExpanded ? "chevron.up" : "chevron.down")
          .scaledFont(size: 9, weight: .semibold, relativeTo: .caption2)
      }
      .foregroundStyle(DS.Colors.accent)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Subtasks \(self.task.subtaskProgress)")
    .accessibilityHint(self.isExpanded ? "Double tap to collapse" : "Double tap to expand")
  }

  private var hiddenIndicator: some View {
    HStack(spacing: 3) {
      Image(systemName: "eye.slash")
        .scaledFont(size: 11, relativeTo: .caption2)
      Text("Hidden")
        .scaledFont(size: 12, relativeTo: .caption)
    }
    .foregroundStyle(.secondary)
  }
}

/// Displays task tags as pills
struct TaskRowTags: View {
  let tags: [TagDTO]

  var body: some View {
    HStack(spacing: DS.Spacing.xs) {
      ForEach(self.tags.prefix(2)) { tag in
        Text(tag.name)
          .font(DS.Typography.caption2.weight(.medium))
          .foregroundStyle(tag.tagColor)
          .padding(.horizontal, DS.Spacing.sm)
          .padding(.vertical, DS.Spacing.xxs)
          .background(tag.tagColor.opacity(DS.Opacity.tintBackground))
          .clipShape(Capsule())
      }

      if self.tags.count > 2 {
        Text("+\(self.tags.count - 2)")
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
