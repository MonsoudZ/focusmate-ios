import SwiftUI

/// Subtask row component
/// Uses onTapGesture instead of Button to avoid List edit mode intercepting taps
struct SubtaskRow: View {
  let subtask: SubtaskDTO
  let canEdit: Bool
  let onComplete: () async -> Void
  let onDelete: () async -> Void
  let onTap: () -> Void

  @State private var isCompleting = false
  @State private var isDeleting = false

  init(
    subtask: SubtaskDTO,
    canEdit: Bool,
    onComplete: @escaping () async -> Void,
    onDelete: @escaping () async -> Void = {},
    onTap: @escaping () -> Void = {}
  ) {
    self.subtask = subtask
    self.canEdit = canEdit
    self.onComplete = onComplete
    self.onDelete = onDelete
    self.onTap = onTap
  }

  var body: some View {
    HStack(spacing: DS.Spacing.sm) {
      // Checkbox — onTapGesture to bypass List edit mode button interception
      self.checkboxView
        .frame(width: DS.Size.checkboxSmall, height: DS.Size.checkboxSmall)
        .contentShape(Rectangle())
        .onTapGesture {
          guard self.canEdit, !self.isCompleting else { return }
          HapticManager.selection()
          Task {
            self.isCompleting = true
            await self.onComplete()
            self.isCompleting = false
          }
        }
        .accessibilityLabel(self.subtask.isCompleted ? "Completed" : "Not completed")
        .accessibilityHint("Double tap to toggle completion")
        .accessibilityAddTraits(.isButton)

      // Title
      Text(self.subtask.title)
        .font(DS.Typography.caption)
        .strikethrough(self.subtask.isCompleted)
        .foregroundStyle(self.subtask.isCompleted ? .secondary : .primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
          guard self.canEdit else { return }
          HapticManager.selection()
          self.onTap()
        }
        .accessibilityLabel("Subtask: \(self.subtask.title)")
        .accessibilityHint(self.canEdit ? "Double tap to edit" : "")
        .accessibilityAddTraits(.isButton)

      // Delete
      if self.canEdit {
        self.deleteButton
      }
    }
    .padding(.horizontal, DS.Spacing.md)
    .padding(.vertical, DS.Spacing.sm)
    .opacity(self.subtask.isCompleted ? 0.7 : 1.0)
  }

  // MARK: - Subviews

  @ViewBuilder
  private var checkboxView: some View {
    if self.isCompleting {
      ProgressView()
        .scaleEffect(0.6)
        .frame(width: DS.Size.checkboxSmall, height: DS.Size.checkboxSmall)
    } else {
      Image(systemName: self.subtask.isCompleted ? DS.Icon.circleChecked : DS.Icon.circle)
        .scaledFont(size: DS.Size.checkboxSmall, relativeTo: .callout)
        .foregroundStyle(self.subtask.isCompleted ? DS.Colors.success : .secondary)
    }
  }

  private var deleteButton: some View {
    Group {
      if self.isDeleting {
        ProgressView()
          .scaleEffect(0.6)
          .frame(width: 28, height: 28)
      } else {
        Image(systemName: "xmark.circle.fill")
          .scaledFont(size: DS.Size.iconSmall, relativeTo: .footnote)
          .foregroundStyle(Color(.tertiaryLabel))
          .frame(width: 28, height: 28)
          .contentShape(Rectangle())
      }
    }
    .onTapGesture {
      guard !self.isDeleting else { return }
      HapticManager.warning()
      Task {
        self.isDeleting = true
        await self.onDelete()
        self.isDeleting = false
      }
    }
    .accessibilityLabel("Delete subtask")
    .accessibilityHint("Double tap to delete \(self.subtask.title)")
    .accessibilityAddTraits(.isButton)
  }
}
