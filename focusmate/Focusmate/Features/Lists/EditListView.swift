import SwiftUI

struct EditListView: View {
    let list: ListDTO
    let listService: ListService
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var description: String
    @State private var selectedColor: String
    @State private var isLoading = false
    @State private var error: FocusmateError?
    
    init(list: ListDTO, listService: ListService) {
        self.list = list
        self.listService = listService
        _name = State(initialValue: list.name)
        _description = State(initialValue: list.description ?? "")
        _selectedColor = State(initialValue: list.color ?? "blue")
    }

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
            .navigationTitle("Edit List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await updateList() }
                    }
                    .disabled(name.isEmpty || isLoading)
                }
            }
            .errorBanner($error)
        }
    }
    
    private func updateList() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await listService.updateList(
                id: list.id,
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
            self.error = .custom("UPDATE_ERROR", error.localizedDescription)
            HapticManager.error()
        }
    }
}
