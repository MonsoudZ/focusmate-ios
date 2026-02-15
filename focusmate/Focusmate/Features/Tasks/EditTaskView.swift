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
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "pencil.line")
                            .foregroundStyle(DS.Colors.accent)
                            .frame(width: 24)
                        TextField("Task title", text: $viewModel.title)
                            .font(DS.Typography.body)
                    }

                    TextField("Notes (optional)", text: $viewModel.note, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Due Date") {
                    if viewModel.originalHadDueDate && viewModel.hasDueDate {
                        // Read-only display for tasks that originally had a due date
                        HStack {
                            Text("Due")
                            Spacer()
                            if let dueDate = viewModel.finalDueDate {
                                Text(dueDate.formatted(date: .abbreviated, time: viewModel.hasSpecificTime ? .shortened : .omitted))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Remove due date option
                        Button(role: .destructive) {
                            viewModel.hasDueDate = false
                        } label: {
                            HStack {
                                Image(systemName: "calendar.badge.minus")
                                Text("Remove due date")
                            }
                        }
                    } else {
                        // UI for tasks without due date (or after removal)
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
                }

                Section("Priority") {
                    PriorityPicker(selected: $viewModel.selectedPriority)
                        .padding(.vertical, DS.Spacing.xs)
                }

                Section {
                    StarredRow(isStarred: $viewModel.isStarred)
                }

                Section("Tags") {
                    TagPickerView(
                        selectedTagIds: $viewModel.selectedTagIds,
                        availableTags: viewModel.availableTags,
                        onCreateTag: { showingCreateTag = true }
                    )
                }

                Section("Color (Optional)") {
                    TaskColorPicker(selected: $viewModel.selectedColor)
                        .padding(.vertical, DS.Spacing.sm)
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
            .floatingErrorBanner($viewModel.error)
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
                CreateTagView(tagService: viewModel.tagService) { newTag in
                    viewModel.availableTags.append(newTag)
                    viewModel.selectedTagIds.insert(newTag.id)
                }
            }
        }
    }
}
