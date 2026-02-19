import SwiftUI

/// Subtasks card with expandable list and add button
struct TaskDetailSubtasksCard: View {
  let subtasks: [SubtaskDTO]
  let hasSubtasks: Bool
  let canEdit: Bool
  let subtaskProgressText: String
  @Binding var isExpanded: Bool
  let onAddSubtask: () -> Void
  let onToggleComplete: (SubtaskDTO) async -> Void
  let onDelete: (SubtaskDTO) async -> Void
  let onEdit: (SubtaskDTO) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header
      Button {
        withAnimation(.easeInOut(duration: 0.2)) {
          self.isExpanded.toggle()
        }
      } label: {
        HStack {
          Image(systemName: "checklist")
            .foregroundStyle(.secondary)
          Text("Subtasks")
            .font(.headline)
          if self.hasSubtasks {
            Text("(\(self.subtaskProgressText))")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          Spacer()
          Image(systemName: self.isExpanded ? "chevron.up" : "chevron.down")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .padding(DS.Spacing.md)
      }
      .buttonStyle(.plain)

      if self.isExpanded {
        Divider()
          .padding(.horizontal, DS.Spacing.md)

        // Subtask list
        if self.hasSubtasks {
          VStack(spacing: 0) {
            ForEach(self.subtasks) { subtask in
              SubtaskRow(
                subtask: subtask,
                canEdit: self.canEdit,
                onComplete: {
                  await self.onToggleComplete(subtask)
                },
                onDelete: {
                  await self.onDelete(subtask)
                },
                onTap: {
                  self.onEdit(subtask)
                }
              )

              if subtask.id != self.subtasks.last?.id {
                Divider()
                  .padding(.leading, 52)
              }
            }
          }
        }

        // Add subtask button
        if self.canEdit {
          if self.hasSubtasks {
            Divider()
              .padding(.leading, 52)
          }

          Button {
            self.onAddSubtask()
          } label: {
            HStack(spacing: DS.Spacing.sm) {
              Image(systemName: "plus.circle")
                .font(.system(size: DS.Size.iconMedium))
              Text("Add subtask")
                .font(DS.Typography.caption)
              Spacer()
            }
            .foregroundStyle(DS.Colors.accent)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
          }
          .buttonStyle(.plain)
        }
      }
    }
    .background(DS.Colors.surfaceElevated)
    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
    .shadow(DS.Shadow.md)
  }
}
