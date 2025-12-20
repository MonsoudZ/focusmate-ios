import SwiftUI

struct EditListView: View {
    let list: ListDTO
    let listService: ListService
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var description: String
    @State private var isLoading = false
    @State private var error: FocusmateError?

    init(list: ListDTO, listService: ListService) {
        self.list = list
        self.listService = listService
        _name = State(initialValue: list.name)
        _description = State(initialValue: list.description ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("List Details") {
                    TextField("List Name", text: $name)
                    TextField("Description (Optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
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
            .alert("Error", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                if let error = error {
                    Text(error.message)
                }
            }
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
                description: description.isEmpty ? nil : description
            )
            dismiss()
        } catch let err as FocusmateError {
            error = err
        } catch {
            self.error = .custom("UPDATE_ERROR", error.localizedDescription)
        }
    }
}
