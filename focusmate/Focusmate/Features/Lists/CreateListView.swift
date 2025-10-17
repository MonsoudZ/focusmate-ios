import SwiftUI

struct CreateListView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var listViewModel: ListViewModel
    
    @State private var name = ""
    @State private var description = ""
    
    init(listService: ListService) {
        self._listViewModel = StateObject(wrappedValue: ListViewModel(listService: listService))
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
            .navigationTitle("New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task {
                            await createList()
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
    
    private func createList() async {
        await listViewModel.createList(
            name: name,
            description: description.isEmpty ? nil : description
        )
        
        if listViewModel.error == nil {
            dismiss()
        }
    }
}
