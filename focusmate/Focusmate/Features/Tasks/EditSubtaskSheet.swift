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

          TextField("What needs to be done?", text: self.$title)
            .font(.body)
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .focused(self.$isFocused)
            .submitLabel(.done)
            .onSubmit {
              self.saveSubtask()
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
            self.dismiss()
          }
          .buttonStyle(IntentiaToolbarCancelStyle())
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            self.saveSubtask()
          }
          .buttonStyle(IntentiaToolbarPrimaryStyle())
          .disabled(self.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || self.isSaving)
        }
      }
      .onAppear {
        self.isFocused = true
      }
    }
    .presentationDetents([.medium])
  }

  private func saveSubtask() {
    let trimmedTitle = self.title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty, !self.isSaving else { return }

    // Only save if changed
    guard trimmedTitle != self.subtask.title else {
      self.dismiss()
      return
    }

    self.isSaving = true
    Task {
      await self.onSave(trimmedTitle)
      await MainActor.run {
        self.dismiss()
      }
    }
  }
}
