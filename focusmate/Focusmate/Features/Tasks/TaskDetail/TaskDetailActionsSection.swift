import SwiftUI

/// Action buttons section (complete/delete)
struct TaskDetailActionsSection: View {
    let task: TaskDTO
    let canEdit: Bool
    let onComplete: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            if canEdit {
                Button {
                    onComplete()
                } label: {
                    Label(
                        task.isCompleted ? "Mark Incomplete" : "Mark Complete",
                        systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(IntentiaPrimaryButtonStyle())
                .tint(task.isCompleted ? DS.Colors.warning : DS.Colors.success)
            }

            if task.can_delete ?? true {
                Button(role: .destructive) {
                    onDelete()
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
