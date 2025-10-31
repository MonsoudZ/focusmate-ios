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
    _listViewModel = StateObject(wrappedValue: ListViewModel(listService: listService))
    _name = State(initialValue: list.title)
    _description = State(initialValue: "") // ListDTO doesn't have description field
  }

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("List Details")) {
          TextField("List Name", text: self.$name)
          TextField("Description (Optional)", text: self.$description, axis: .vertical)
            .lineLimit(3 ... 6)
        }
      }
      .navigationTitle("Edit List")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            self.dismiss()
          }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Save") {
            Task {
              await self.updateList()
            }
          }
          .disabled(self.name.isEmpty || self.listViewModel.isLoading)
        }
      }
      .alert("Error", isPresented: .constant(self.listViewModel.error != nil)) {
        Button("OK") {
          self.listViewModel.clearError()
        }
      } message: {
        if let error = listViewModel.error {
          Text(error.errorDescription ?? "An error occurred")
        }
      }
    }
  }

  private func updateList() async {
    await self.listViewModel.updateList(
      id: self.list.id,
      name: self.name,
      description: self.description.isEmpty ? nil : self.description
    )

    if self.listViewModel.error == nil {
      self.dismiss()
    }
  }
}
