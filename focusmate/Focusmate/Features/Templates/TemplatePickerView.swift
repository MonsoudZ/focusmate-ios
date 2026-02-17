import SwiftUI

struct TemplatePickerView: View {
  let listService: ListService
  let taskService: TaskService
  let onCreated: (ListDTO) -> Void

  @State private var viewModel: TemplateCreationViewModel
  @Environment(\.dismiss) private var dismiss

  init(
    listService: ListService,
    taskService: TaskService,
    onCreated: @escaping (ListDTO) -> Void
  ) {
    self.listService = listService
    self.taskService = taskService
    self.onCreated = onCreated
    _viewModel = State(initialValue: TemplateCreationViewModel(
      listService: listService,
      taskService: taskService
    ))
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(spacing: DS.Spacing.lg) {
          ForEach(TemplateCatalog.grouped(), id: \.category) { group in
            Section {
              ForEach(group.templates) { template in
                Button {
                  createTemplate(template)
                } label: {
                  TemplateCardView(
                    template: template,
                    isCreating: viewModel.creatingTemplateId == template.id,
                    isDisabled: viewModel.isCreating && viewModel.creatingTemplateId != template.id
                  )
                }
                .buttonStyle(IntentiaCardButtonStyle())
                .disabled(viewModel.isCreating)
              }
            } header: {
              SectionHeader(
                group.category.rawValue,
                icon: group.category.icon,
                count: group.templates.count
              )
            }
          }
        }
        .padding(DS.Spacing.md)
      }
      .surfaceBackground()
      .navigationTitle("Templates")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
          .disabled(viewModel.isCreating)
        }
      }
    }
    .floatingErrorBanner($viewModel.error)
  }

  // MARK: - Actions

  private func createTemplate(_ template: ListTemplate) {
    HapticManager.selection()
    Task {
      guard let list = await viewModel.createFromTemplate(template) else { return }

      if viewModel.failedTaskCount > 0 {
        Logger.warning(
          "Template '\(template.id)' created with \(viewModel.failedTaskCount) failed tasks",
          category: .ui
        )
      }

      dismiss()
      onCreated(list)
    }
  }
}
