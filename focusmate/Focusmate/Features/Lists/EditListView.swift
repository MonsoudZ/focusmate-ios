import SwiftUI

struct EditListView: View {
    @Environment(\.dismiss) var dismiss

    @State private var viewModel: EditListViewModel
    @State private var showingCreateTag = false

    init(list: ListDTO, listService: ListService, tagService: TagService) {
        _viewModel = State(initialValue: EditListViewModel(list: list, listService: listService, tagService: tagService))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("List Details") {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "list.bullet.rectangle")
                            .foregroundStyle(DS.Colors.accent)
                            .frame(width: 24)
                        TextField("List name", text: $viewModel.name)
                            .font(DS.Typography.body)
                    }

                    TextField("Description (optional)", text: $viewModel.description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Color") {
                    ListColorPicker(selected: $viewModel.selectedColor)
                        .padding(.vertical, DS.Spacing.sm)
                }

                Section("Tags") {
                    TagPickerView(
                        selectedTagIds: $viewModel.selectedTagIds,
                        availableTags: viewModel.availableTags,
                        onCreateTag: { showingCreateTag = true }
                    )
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
                    .buttonStyle(IntentiaToolbarCancelStyle())
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.updateList() {
                                dismiss()
                            }
                        }
                    }
                    .buttonStyle(IntentiaToolbarPrimaryStyle())
                    .disabled(viewModel.name.isEmpty || viewModel.isLoading)
                }
            }
            .floatingErrorBanner($viewModel.error)
            .task {
                await viewModel.loadTags()
            }
            .sheet(isPresented: $showingCreateTag) {
                CreateTagView(tagService: viewModel.tagService) {
                    Task { await viewModel.loadTags() }
                }
            }
        }
    }
}
