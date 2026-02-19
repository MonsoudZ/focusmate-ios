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
            TextField("Task title", text: self.$viewModel.title)
              .font(DS.Typography.body)
          }

          TextField("Notes (optional)", text: self.$viewModel.note, axis: .vertical)
            .lineLimit(3 ... 6)
        }

        Section("Due Date") {
          Toggle("Has due date", isOn: self.$viewModel.hasDueDate)

          if self.viewModel.hasDueDate {
            DatePicker(
              "Date",
              selection: self.$viewModel.dueDate,
              in: Calendar.current.startOfDay(for: Date())...,
              displayedComponents: [.date]
            )

            Toggle("Specific time", isOn: self.$viewModel.hasSpecificTime)

            if self.viewModel.hasSpecificTime {
              DatePicker(
                "Time",
                selection: self.$viewModel.dueTime,
                in: self.viewModel.minimumTime...,
                displayedComponents: [.hourAndMinute]
              )
            }
          }
        }

        Section("Priority") {
          PriorityPicker(selected: self.$viewModel.selectedPriority)
            .padding(.vertical, DS.Spacing.xs)
        }

        Section("Starred") {
          StarredRow(isStarred: self.$viewModel.isStarred)
        }

        Section("Tags") {
          TagPickerView(
            selectedTagIds: self.$viewModel.selectedTagIds,
            availableTags: self.viewModel.availableTags,
            onCreateTag: { self.showingCreateTag = true }
          )
        }

        Section("Color") {
          TaskColorPicker(selected: self.$viewModel.selectedColor)
            .padding(.vertical, DS.Spacing.sm)
        }
      }
      .surfaceFormBackground()
      .navigationTitle("Edit Task")
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
            Task { await self.viewModel.submit() }
          }
          .buttonStyle(IntentiaToolbarPrimaryStyle())
          .disabled(!self.viewModel.canSubmit)
        }
      }
      .floatingErrorBanner(self.$viewModel.error)
      .task {
        await self.viewModel.loadTags()
      }
      .onAppear {
        self.viewModel.onSave = self.externalOnSave
        self.viewModel.onDismiss = { self.dismiss() }
        self.viewModel.onRescheduleRequired = { _, task in
          self.rescheduleTask = task
        }
      }
      .sheet(item: self.$rescheduleTask) { task in
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
      .onChange(of: self.viewModel.dueDate) { _, _ in
        self.viewModel.dueDateChanged()
      }
      .onChange(of: self.viewModel.hasSpecificTime) { _, _ in
        self.viewModel.hasSpecificTimeChanged()
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
