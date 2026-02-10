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
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "checklist")
                        .foregroundStyle(.secondary)
                    Text("Subtasks")
                        .font(.headline)
                    if hasSubtasks {
                        Text("(\(subtaskProgressText))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(DS.Spacing.md)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .padding(.horizontal, DS.Spacing.md)

                // Subtask list
                if hasSubtasks {
                    VStack(spacing: 0) {
                        ForEach(subtasks) { subtask in
                            SubtaskRow(
                                subtask: subtask,
                                canEdit: canEdit,
                                onComplete: {
                                    await onToggleComplete(subtask)
                                },
                                onDelete: {
                                    await onDelete(subtask)
                                },
                                onTap: {
                                    onEdit(subtask)
                                }
                            )

                            if subtask.id != subtasks.last?.id {
                                Divider()
                                    .padding(.leading, 52)
                            }
                        }
                    }
                }

                // Add subtask button
                if canEdit {
                    if hasSubtasks {
                        Divider()
                            .padding(.leading, 52)
                    }

                    Button {
                        onAddSubtask()
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
