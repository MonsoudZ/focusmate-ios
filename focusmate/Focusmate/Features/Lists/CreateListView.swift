import SwiftUI

struct CreateListView: View {
    @Environment(\.dismiss) var dismiss
    let listService: ListService

    @State private var name = ""
    @State private var description = ""
    @State private var selectedColor = "blue"
    @State private var isLoading = false
    @State private var error: FocusmateError?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("List Details") {
                    TextField("List Name", text: $name)
                    TextField("Description (Optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Color") {
                    ListColorPicker(selected: $selectedColor)
                        .padding(.vertical, 8)
                }
            }
            .surfaceFormBackground()
            .navigationTitle("New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await createList() }
                    }
                    .disabled(name.isEmpty || isLoading)
                }
            }
            .errorBanner($error)
        }
    }
    
    private func createList() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await listService.createList(
                name: trimmedName,
                description: description.isEmpty ? nil : description,
                color: selectedColor
            )
            HapticManager.success()
            dismiss()
        } catch let err as FocusmateError {
            error = err
            HapticManager.error()
        } catch {
            self.error = .custom("CREATE_ERROR", error.localizedDescription)
            HapticManager.error()
        }
    }
}
