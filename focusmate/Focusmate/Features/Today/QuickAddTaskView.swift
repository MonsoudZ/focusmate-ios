import SwiftUI

struct QuickAddTaskView: View {
    @StateObject private var viewModel: QuickAddViewModel
    @Environment(\.dismiss) var dismiss
    @FocusState private var isTitleFocused: Bool

    init(listService: ListService, taskService: TaskService, onTaskCreated: (() async -> Void)? = nil) {
        let vm = QuickAddViewModel(listService: listService, taskService: taskService)
        vm.onTaskCreated = onTaskCreated
        _viewModel = StateObject(wrappedValue: vm)
    }

    var body: some View {
        NavigationStack {
            Form {
                if viewModel.isLoadingLists {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                } else if viewModel.lists.isEmpty {
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
                    TextField("Task title", text: $viewModel.title)
                        .focused($isTitleFocused)

                    Picker("List", selection: $viewModel.selectedList) {
                        ForEach(viewModel.lists) { list in
                            Text(list.name).tag(list as ListDTO?)
                        }
                    }

                    Section {
                        Label("Due today", systemImage: DS.Icon.calendar)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Button("Add") {
                            Task {
                                if await viewModel.createTask() {
                                    dismiss()
                                }
                            }
                        }
                        .disabled(!viewModel.canSubmit)
                    }
                }
            }
            .task {
                await viewModel.loadLists()
                isTitleFocused = !viewModel.lists.isEmpty
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error?.message ?? "Something went wrong. Please try again.")
            }
        }
    }
}
