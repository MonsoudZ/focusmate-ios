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
            VStack(spacing: DS.Spacing.lg) {
                // Parent task info
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Adding subtask to:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(parentTask.title)
                        .font(.body.weight(.medium))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
                
                // Title input
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Subtask")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextField("What needs to be done?", text: $title)
                        .font(.body)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            saveSubtask()
                        }
                }
                
                Spacer()
            }
            .padding()
            .surfaceBackground()
            .navigationTitle("Add Subtask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(IntentiaToolbarCancelStyle())
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        saveSubtask()
                    }
                    .buttonStyle(IntentiaToolbarPrimaryStyle())
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
