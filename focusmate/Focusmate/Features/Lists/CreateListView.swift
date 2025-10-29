import SwiftUI

struct CreateListView: View {
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject var appState: AppState
  @StateObject private var listViewModel: ListViewModel

  @State private var name = ""
  @State private var description = ""

  init(listService: ListService) {
    _listViewModel = StateObject(wrappedValue: ListViewModel(listService: listService))
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
      .navigationTitle("New List")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            self.dismiss()
          }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Create") {
            Task {
              await self.createList()
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

  private func createList() async {
    await self.listViewModel.createList(
      name: self.name,
      description: self.description.isEmpty ? nil : self.description
    )

    if self.listViewModel.error == nil {
      self.dismiss()
    }
  }
}
