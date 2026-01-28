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
            VStack(spacing: DS.Spacing.lg) {
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
