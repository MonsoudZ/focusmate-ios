import SwiftUI

/// Action buttons section (complete/delete)
struct TaskDetailActionsSection: View {
  let task: TaskDTO
  let canEdit: Bool
  let onComplete: () -> Void
  let onDelete: () -> Void

  var body: some View {
    VStack(spacing: DS.Spacing.sm) {
      if self.canEdit {
        Button {
          self.onComplete()
        } label: {
          Label(
            self.task.isCompleted ? "Mark Incomplete" : "Mark Complete",
            systemImage: self.task.isCompleted ? "arrow.uturn.backward" : "checkmark"
          )
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(IntentiaPrimaryButtonStyle())
        .tint(self.task.isCompleted ? DS.Colors.warning : DS.Colors.success)
      }

      if self.task.can_delete ?? true {
        Button(role: .destructive) {
          self.onDelete()
        } label: {
          Label("Delete Task", systemImage: DS.Icon.trash)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(IntentiaSecondaryButtonStyle())
      }
    }
    .padding(.top, DS.Spacing.md)
  }
}
