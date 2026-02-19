import SwiftUI

struct QuickAddTaskView: View {
  @State private var viewModel: QuickAddViewModel
  @Environment(\.dismiss) var dismiss
  @FocusState private var isTitleFocused: Bool

  init(listService: ListService, taskService: TaskService, onTaskCreated: (() async -> Void)? = nil) {
    let vm = QuickAddViewModel(listService: listService, taskService: taskService)
    vm.onTaskCreated = onTaskCreated
    _viewModel = State(initialValue: vm)
  }

  var body: some View {
    NavigationStack {
      Form {
        if self.viewModel.isLoadingLists {
          Section {
            HStack {
              Spacer()
              ProgressView()
              Spacer()
            }
          }
        } else if self.viewModel.lists.isEmpty {
          Section {
            VStack(spacing: DS.Spacing.sm) {
              Image(systemName: DS.Icon.emptyList)
                .font(.title2)
                .foregroundStyle(.secondary)
              Text("Create a list first")
                .font(.subheadline)
                .foregroundStyle(.secondary)
              Text("You need at least one list before adding tasks.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
          }
        } else {
          TextField("Task title", text: self.$viewModel.title)
            .focused(self.$isTitleFocused)

          Picker("List", selection: self.$viewModel.selectedList) {
            ForEach(self.viewModel.lists) { list in
              Text(list.name).tag(list as ListDTO?)
            }
          }

          Section {
            Toggle(isOn: self.$viewModel.hasSpecificTime) {
              Label("Set a time", systemImage: DS.Icon.clock)
            }

            if self.viewModel.hasSpecificTime {
              DatePicker(
                "Time",
                selection: self.$viewModel.dueTime,
                displayedComponents: .hourAndMinute
              )
            } else {
              Label("Due today (anytime)", systemImage: DS.Icon.calendar)
                .foregroundStyle(.secondary)
            }
          }
        }
      }
      .surfaceFormBackground()
      .navigationTitle("Quick Add")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            self.dismiss()
          }
          .buttonStyle(IntentiaToolbarCancelStyle())
        }

        ToolbarItem(placement: .confirmationAction) {
          if self.viewModel.isLoading {
            ProgressView()
          } else {
            Button("Add Task") {
              Task {
                if await self.viewModel.createTask() {
                  self.dismiss()
                }
              }
            }
            .buttonStyle(IntentiaToolbarPrimaryStyle())
            .disabled(!self.viewModel.canSubmit)
          }
        }
      }
      .task {
        await self.viewModel.loadLists()
        self.isTitleFocused = !self.viewModel.lists.isEmpty
      }
      .alert("Error", isPresented: .init(
        get: { self.viewModel.error != nil },
        set: { if !$0 { self.viewModel.error = nil } }
      )) {
        Button("OK") { self.viewModel.error = nil }
      } message: {
        Text(self.viewModel.error?.message ?? "Something went wrong. Please try again.")
      }
    }
  }
}
