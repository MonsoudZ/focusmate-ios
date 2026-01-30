import SwiftUI

struct EditTaskView: View {
    @Environment(\.dismiss) var dismiss

    @State private var viewModel: TaskFormViewModel
    @State private var showingCreateTag = false

    private let externalOnSave: (() -> Void)?

    init(listId: Int, task: TaskDTO, taskService: TaskService, tagService: TagService, onSave: (() -> Void)? = nil) {
        self.externalOnSave = onSave
        _viewModel = State(initialValue: TaskFormViewModel(
            mode: .edit(listId: listId, task: task),
            taskService: taskService,
            tagService: tagService
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    TextField("Title", text: $viewModel.title)

                    TextField("Notes (Optional)", text: $viewModel.note, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Due Date") {
                    Toggle("Set due date", isOn: $viewModel.hasDueDate)

                    if viewModel.hasDueDate {
                        DatePicker(
                            "Date",
                            selection: $viewModel.dueDate,
                            in: Calendar.current.startOfDay(for: Date())...,
                            displayedComponents: [.date]
                        )

                        Toggle("Specific time", isOn: $viewModel.hasSpecificTime)

                        if viewModel.hasSpecificTime {
                            DatePicker(
                                "Time",
                                selection: $viewModel.dueTime,
                                in: viewModel.minimumTime...,
                                displayedComponents: [.hourAndMinute]
                            )
                        }
                    }
                }

                Section("Priority") {
                    Picker("Priority", selection: $viewModel.selectedPriority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            HStack {
                                if let icon = priority.icon {
                                    Image(systemName: icon)
                                        .foregroundColor(priority.color)
                                }
                                Text(priority.label)
                            }
                            .tag(priority)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    Toggle(isOn: $viewModel.isStarred) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("Starred")
                        }
                    }
                }

                Section("Tags") {
                    TagPickerView(
                        selectedTagIds: $viewModel.selectedTagIds,
                        availableTags: viewModel.availableTags,
                        onCreateTag: { showingCreateTag = true }
                    )
                }

                Section("Color (Optional)") {
                    OptionalColorPicker(selected: $viewModel.selectedColor)
                        .padding(.vertical, 8)
                }
            }
            .surfaceFormBackground()
            .navigationTitle("Edit Task")
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
                        Task { await viewModel.submit() }
                    }
                    .buttonStyle(IntentiaToolbarPrimaryStyle())
                    .disabled(!viewModel.canSubmit)
                }
            }
            .errorBanner($viewModel.error)
            .task {
                await viewModel.loadTags()
            }
            .onAppear {
                viewModel.onSave = externalOnSave
                viewModel.onDismiss = { dismiss() }
            }
            .onChange(of: viewModel.dueDate) { _, _ in
                viewModel.dueDateChanged()
            }
            .onChange(of: viewModel.hasSpecificTime) { _, _ in
                viewModel.hasSpecificTimeChanged()
            }
            .sheet(isPresented: $showingCreateTag) {
                CreateTagView(tagService: viewModel.tagService) {
                    Task { await viewModel.loadTags() }
                }
            }
        }
    }
}
