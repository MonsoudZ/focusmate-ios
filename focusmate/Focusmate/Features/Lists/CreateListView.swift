import SwiftUI

struct CreateListView: View {
    @Environment(\.dismiss) var dismiss
    @FocusState private var isNameFocused: Bool

    @State private var viewModel: CreateListViewModel
    @State private var showingCreateTag = false

    init(listService: ListService, tagService: TagService) {
        _viewModel = State(initialValue: CreateListViewModel(listService: listService, tagService: tagService))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("List Details") {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "list.bullet.rectangle")
                            .foregroundStyle(DS.Colors.accent)
                            .frame(width: 24)
                        TextField("What's this list for?", text: $viewModel.name)
                            .font(DS.Typography.body)
                            .focused($isNameFocused)
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
            .floatingErrorBanner($viewModel.error)
            .task {
                await viewModel.loadTags()
            }
            .task {
                try? await Task.sleep(for: .seconds(0.5))
                isNameFocused = true
            }
            .sheet(isPresented: $showingCreateTag) {
                CreateTagView(tagService: viewModel.tagService) {
                    Task { await viewModel.loadTags() }
                }
            }
        }
    }
}
