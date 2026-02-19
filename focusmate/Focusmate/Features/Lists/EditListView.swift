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
            TextField("List name", text: self.$viewModel.name)
              .font(DS.Typography.body)
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
      .navigationTitle("Edit List")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            self.dismiss()
          }
          .buttonStyle(IntentiaToolbarCancelStyle())
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            Task {
              if await self.viewModel.updateList() {
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
      .sheet(isPresented: self.$showingCreateTag) {
        CreateTagView(tagService: self.viewModel.tagService) { newTag in
          self.viewModel.availableTags.append(newTag)
          self.viewModel.selectedTagIds.insert(newTag.id)
        }
      }
    }
  }
}
