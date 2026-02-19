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
            TextField("What's this list for?", text: self.$viewModel.name)
              .font(DS.Typography.body)
              .focused(self.$isNameFocused)
          }

          TextField("Description (optional)", text: self.$viewModel.description, axis: .vertical)
            .lineLimit(3 ... 6)
        }

        Section("Color") {
          ListColorPicker(selected: self.$viewModel.selectedColor)
            .padding(.vertical, DS.Spacing.sm)
        }

        Section("Tags") {
          TagPickerView(
            selectedTagIds: self.$viewModel.selectedTagIds,
            availableTags: self.viewModel.availableTags,
            onCreateTag: { self.showingCreateTag = true }
          )
        }
      }
      .surfaceFormBackground()
      .navigationTitle("New List")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            self.dismiss()
          }
          .buttonStyle(IntentiaToolbarCancelStyle())
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("Create List") {
            Task {
              if await self.viewModel.createList() {
                self.dismiss()
              }
            }
          }
          .buttonStyle(IntentiaToolbarPrimaryStyle())
          .disabled(self.viewModel.name.isEmpty || self.viewModel.isLoading)
        }
      }
      .floatingErrorBanner(self.$viewModel.error)
      .task {
        await self.viewModel.loadTags()
      }
      .task {
        try? await Task.sleep(for: .seconds(0.5))
        self.isNameFocused = true
      }
      .sheet(isPresented: self.$showingCreateTag) {
        CreateTagView(tagService: self.viewModel.tagService) { newTag in
          self.viewModel.availableTags.append(newTag)
          self.viewModel.selectedTagIds.insert(newTag.id)
        }
      }
    }
  }
}
