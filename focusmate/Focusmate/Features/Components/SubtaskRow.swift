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
            checkboxView
                .frame(width: DS.Size.checkboxSmall, height: DS.Size.checkboxSmall)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard canEdit, !isCompleting else { return }
                    HapticManager.selection()
                    Task {
                        isCompleting = true
                        await onComplete()
                        isCompleting = false
                    }
                }
                .accessibilityLabel(subtask.isCompleted ? "Completed" : "Not completed")
                .accessibilityHint("Double tap to toggle completion")
                .accessibilityAddTraits(.isButton)

            // Title
            Text(subtask.title)
                .font(DS.Typography.caption)
                .strikethrough(subtask.isCompleted)
                .foregroundStyle(subtask.isCompleted ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard canEdit else { return }
                    HapticManager.selection()
                    onTap()
                }
                .accessibilityLabel("Subtask: \(subtask.title)")
                .accessibilityHint(canEdit ? "Double tap to edit" : "")
                .accessibilityAddTraits(.isButton)

            // Delete
            if canEdit {
                deleteButton
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .opacity(subtask.isCompleted ? 0.7 : 1.0)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var checkboxView: some View {
        if isCompleting {
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: DS.Size.checkboxSmall, height: DS.Size.checkboxSmall)
        } else {
            Image(systemName: subtask.isCompleted ? DS.Icon.circleChecked : DS.Icon.circle)
                .font(.system(size: DS.Size.checkboxSmall))
                .foregroundStyle(subtask.isCompleted ? DS.Colors.success : .secondary)
        }
    }

    private var deleteButton: some View {
        Group {
            if isDeleting {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 28, height: 28)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: DS.Size.iconSmall))
                    .foregroundStyle(Color(.tertiaryLabel))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
        }
        .onTapGesture {
            guard !isDeleting else { return }
            HapticManager.warning()
            Task {
                isDeleting = true
                await onDelete()
                isDeleting = false
            }
        }
        .accessibilityLabel("Delete subtask")
        .accessibilityHint("Double tap to delete \(subtask.title)")
        .accessibilityAddTraits(.isButton)
    }
}
