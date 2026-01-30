import SwiftUI

struct CreateListView: View {
    @Environment(\.dismiss) var dismiss

    @State private var viewModel: CreateListViewModel

    init(listService: ListService) {
        _viewModel = State(initialValue: CreateListViewModel(listService: listService))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("List Details") {
                    TextField("List Name", text: $viewModel.name)
                    TextField("Description (Optional)", text: $viewModel.description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Color") {
                    ListColorPicker(selected: $viewModel.selectedColor)
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
                    .buttonStyle(IntentiaToolbarCancelStyle())
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create List") {
                        Task {
                            if await viewModel.createList() {
                                dismiss()
                            }
                        }
                    }
                    .buttonStyle(IntentiaToolbarPrimaryStyle())
                    .disabled(viewModel.name.isEmpty || viewModel.isLoading)
                }
            }
            .errorBanner($viewModel.error)
        }
    }
}
