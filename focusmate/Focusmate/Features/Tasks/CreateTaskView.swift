import SwiftUI

struct CreateTaskView: View {
  @Environment(\.dismiss) var dismiss
  @FocusState private var isTitleFocused: Bool

  @State private var viewModel: TaskFormViewModel
  @State private var showingCreateTag = false

  init(listId: Int, taskService: TaskService, tagService: TagService) {
    _viewModel = State(initialValue: TaskFormViewModel(
      mode: .create(listId: listId),
      taskService: taskService,
      tagService: tagService
    ))
  }

  var body: some View {
    NavigationStack {
      Form {
        self.taskDetailsSection
        self.dueDateSection
        self.prioritySection
        self.starredSection
        self.tagsSection
        self.colorSection
      }
      .surfaceFormBackground()
      .navigationTitle("New Task")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            self.dismiss()
          }
          .buttonStyle(IntentiaToolbarCancelStyle())
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("Create Task") {
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
        self.viewModel.onDismiss = { self.dismiss() }
      }
      .task {
        // Brief delay for smooth sheet animation before focusing the title field
        try? await Task.sleep(for: .seconds(0.5))
        self.isTitleFocused = true
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

  // MARK: - Form Sections

  private var taskDetailsSection: some View {
    Section("Task Details") {
      HStack(spacing: DS.Spacing.sm) {
        Image(systemName: "pencil.line")
          .foregroundStyle(DS.Colors.accent)
          .frame(width: 24)
        TextField("What do you need to do?", text: self.$viewModel.title)
          .font(DS.Typography.body)
          .focused(self.$isTitleFocused)
      }

      TextField("Notes (optional)", text: self.$viewModel.note, axis: .vertical)
        .lineLimit(3 ... 6)
    }
  }

  private var dueDateSection: some View {
    Section("Due Date *") {
      HStack(spacing: DS.Spacing.sm) {
        QuickDatePill(
          "Today",
          icon: "sun.max.fill",
          isSelected: self.viewModel.isToday
        ) {
          self.viewModel.setDueDate(daysFromNow: 0)
        }
        QuickDatePill(
          "Tomorrow",
          icon: "sunrise.fill",
          isSelected: self.viewModel.isTomorrow
        ) {
          self.viewModel.setDueDate(daysFromNow: 1)
        }
        QuickDatePill(
          "Next Week",
          icon: "calendar",
          isSelected: self.viewModel.isNextWeek
        ) {
          self.viewModel.setDueDate(daysFromNow: 7)
        }
      }
      .padding(.vertical, DS.Spacing.xs)

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

      self.recurrenceOptions
    }
  }

  @ViewBuilder
  private var recurrenceOptions: some View {
    Picker("Repeat", selection: self.$viewModel.recurrencePattern) {
      ForEach(RecurrencePattern.allCases, id: \.self) { pattern in
        Text(pattern.label).tag(pattern)
      }
    }

    if self.viewModel.recurrencePattern != .none {
      Stepper(
        "Every \(self.viewModel.recurrenceInterval) \(self.viewModel.recurrenceIntervalUnit)",
        value: self.$viewModel.recurrenceInterval,
        in: 1 ... 99
      )

      if self.viewModel.recurrencePattern == .weekly {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
          Text("On these days")
            .font(.caption)
            .foregroundStyle(.secondary)

          WeekdayPicker(selectedDays: self.$viewModel.selectedRecurrenceDays)
        }
      }

      Toggle("End date", isOn: self.$viewModel.hasRecurrenceEndDate)

      if self.viewModel.hasRecurrenceEndDate {
        DatePicker(
          "Ends on",
          selection: Binding(
            get: { self.viewModel.recurrenceEndDate ?? Date().addingTimeInterval(86400 * 30) },
            set: { self.viewModel.recurrenceEndDate = $0 }
          ),
          in: self.viewModel.dueDate...,
          displayedComponents: [.date]
        )
      }
    }
  }

  private var prioritySection: some View {
    Section("Priority") {
      PriorityPicker(selected: self.$viewModel.selectedPriority)
        .padding(.vertical, DS.Spacing.xs)
    }
  }

  private var starredSection: some View {
    Section {
      StarredRow(isStarred: self.$viewModel.isStarred)
    }
  }

  private var tagsSection: some View {
    Section("Tags") {
      TagPickerView(
        selectedTagIds: self.$viewModel.selectedTagIds,
        availableTags: self.viewModel.availableTags,
        onCreateTag: { self.showingCreateTag = true }
      )
    }
  }

  private var colorSection: some View {
    Section("Color (optional)") {
      TaskColorPicker(selected: self.$viewModel.selectedColor)
        .padding(.vertical, DS.Spacing.sm)
    }
  }
}
