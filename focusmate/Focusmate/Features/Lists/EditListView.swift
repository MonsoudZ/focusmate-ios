import SwiftUI

struct EditListView: View {
    let list: ListDTO
    let listService: ListService
    @Environment(\.dismiss) var dismiss
    @StateObject private var listViewModel: ListViewModel
    
    @State private var name: String
    @State private var description: String
    
    init(list: ListDTO, listService: ListService) {
        self.list = list
        self.listService = listService
        self._listViewModel = StateObject(wrappedValue: ListViewModel(listService: listService))
        self._name = State(initialValue: list.name)
        self._description = State(initialValue: list.description ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("List Details")) {
                    TextField("List Name", text: $name)
                    TextField("Description (Optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await updateList()
                        }
                    }
                    .disabled(name.isEmpty || listViewModel.isLoading)
                }
            }
            .alert("Error", isPresented: .constant(listViewModel.error != nil)) {
                Button("OK") {
                    listViewModel.clearError()
                }
            } message: {
                if let error = listViewModel.error {
                    Text(error.errorDescription ?? "An error occurred")
                }
            }
        }
    }
    
    private func updateList() async {
        await listViewModel.updateList(
            id: list.id,
            name: name,
            description: description.isEmpty ? nil : description
        )
        
        if listViewModel.error == nil {
            dismiss()
        }
    }
}
