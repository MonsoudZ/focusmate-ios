import SwiftUI

struct CreateItemView: View {
    let listId: Int
    let itemService: ItemService
    @Environment(\.dismiss) var dismiss
    @StateObject private var itemViewModel: ItemViewModel
    
    @State private var name = ""
    @State private var description = ""
    @State private var dueDate = Date()
    @State private var hasDueDate = false
    
    init(listId: Int, itemService: ItemService) {
        self.listId = listId
        self.itemService = itemService
        self._itemViewModel = StateObject(wrappedValue: ItemViewModel(itemService: itemService))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Item Details")) {
                    TextField("Name", text: $name)
                    
                    TextField("Description (Optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text("Due Date")) {
                    Toggle("Set due date", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("New Item")
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
                            await createItem()
                        }
                    }
                    .disabled(name.isEmpty || itemViewModel.isLoading)
                }
            }
            .alert("Error", isPresented: .constant(itemViewModel.error != nil)) {
                Button("OK") {
                    itemViewModel.clearError()
                }
            } message: {
                if let error = itemViewModel.error {
                    Text(error.errorDescription ?? "An error occurred")
                }
            }
        }
    }
    
    private func createItem() async {
        await itemViewModel.createItem(
            listId: listId,
            name: name,
            description: description.isEmpty ? nil : description,
            dueDate: hasDueDate ? dueDate : nil
        )
        
        if itemViewModel.error == nil {
            dismiss()
        }
    }
}
