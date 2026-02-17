import SwiftUI

struct EditTaskView: View {
    @Environment(\.dismiss) var dismiss

    @State private var viewModel: TaskFormViewModel
    @State private var showingCreateTag = false
    @State private var rescheduleTask: TaskDTO?

    private let externalOnSave: (() -> Void)?
    private let taskService: TaskService

    init(listId: Int, task: TaskDTO, taskService: TaskService, tagService: TagService, onSave: (() -> Void)? = nil) {
        self.externalOnSave = onSave
        self.taskService = taskService
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
                    Toggle("Has due date", isOn: $viewModel.hasDueDate)

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
                    PriorityPicker(selected: $viewModel.selectedPriority)
                        .padding(.vertical, DS.Spacing.xs)
                }

                Section("Starred") {
                    StarredRow(isStarred: $viewModel.isStarred)
                }

                Section("Tags") {
                    TagPickerView(
                        selectedTagIds: $viewModel.selectedTagIds,
                        availableTags: viewModel.availableTags,
                        onCreateTag: { showingCreateTag = true }
                    )
                }

                Section("Color") {
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
                viewModel.onRescheduleRequired = { _, task in
                    rescheduleTask = task
                }
            }
            .sheet(item: $rescheduleTask) { task in
                RescheduleSheet(task: task) { newDate, reason in
                    Task {
                        do {
                            _ = try await self.taskService.rescheduleTask(
                                listId: self.viewModel.listId,
                                taskId: task.id,
                                newDueAt: newDate.ISO8601Format(),
                                reason: reason
                            )
                            HapticManager.success()
                            self.viewModel.onSave?()
                            self.dismiss()
                        } catch {
                            self.viewModel.error = ErrorHandler.shared.handle(error, context: "Rescheduling task")
                            HapticManager.error()
                        }
                    }
                }
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
