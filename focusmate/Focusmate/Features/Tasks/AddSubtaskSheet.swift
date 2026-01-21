import SwiftUI

struct AddSubtaskSheet: View {
    let parentTask: TaskDTO
    let onSave: (String) async -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var isSaving = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Parent task info
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Adding subtask to:")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Text(parentTask.title)
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(DesignSystem.Colors.cardBackground)
                .cornerRadius(DesignSystem.CornerRadius.md)
                
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
            .navigationTitle("Add Subtask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
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
        
        isSaving = true
        Task {
            await onSave(trimmedTitle)
            await MainActor.run {
                dismiss()
            }
        }
    }
}
