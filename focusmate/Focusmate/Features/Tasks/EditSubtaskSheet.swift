import SwiftUI

struct EditSubtaskSheet: View {
    let subtask: SubtaskDTO
    let onSave: (String) async -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var isSaving = false
    @FocusState private var isFocused: Bool
    
    init(subtask: SubtaskDTO, onSave: @escaping (String) async -> Void) {
        self.subtask = subtask
        self.onSave = onSave
        self._title = State(initialValue: subtask.title)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Title input
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Subtask")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    TextField("What needs to be done?", text: $title)
                        .font(DesignSystem.Typography.body)
                        .padding()
                        .background(DesignSystem.Colors.cardBackground)
                        .cornerRadius(DesignSystem.CornerRadius.md)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            saveSubtask()
                        }
                }
                
                Spacer()
            }
            .padding()
            .background(DesignSystem.Colors.background)
            .navigationTitle("Edit Subtask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSubtask()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
        .presentationDetents([.medium])
    }
    
    private func saveSubtask() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !isSaving else { return }
        
        // Only save if changed
        guard trimmedTitle != subtask.title else {
            dismiss()
            return
        }
        
        isSaving = true
        Task {
            await onSave(trimmedTitle)
            await MainActor.run {
                dismiss()
            }
        }
    }
}
