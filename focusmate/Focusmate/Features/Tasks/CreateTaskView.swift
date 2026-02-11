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
                taskDetailsSection
                dueDateSection
                prioritySection
                starredSection
                tagsSection
                colorSection
            }
            .surfaceFormBackground()
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(IntentiaToolbarCancelStyle())
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create Task") {
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
                viewModel.onDismiss = { dismiss() }
            }
            .task {
                // Brief delay for smooth sheet animation before focusing the title field
                try? await Task.sleep(for: .seconds(0.5))
                isTitleFocused = true
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

    // MARK: - Form Sections

    private var taskDetailsSection: some View {
        Section("Task Details") {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "pencil.line")
                    .foregroundStyle(DS.Colors.accent)
                    .frame(width: 24)
                TextField("What do you need to do?", text: $viewModel.title)
                    .font(DS.Typography.body)
                    .focused($isTitleFocused)
            }

            TextField("Notes (optional)", text: $viewModel.note, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private var dueDateSection: some View {
        Section("Due Date *") {
            HStack(spacing: DS.Spacing.sm) {
                QuickDatePill(
                    "Today",
                    icon: "sun.max.fill",
                    isSelected: viewModel.isToday
                ) {
                    viewModel.setDueDate(daysFromNow: 0)
                }
                QuickDatePill(
                    "Tomorrow",
                    icon: "sunrise.fill",
                    isSelected: viewModel.isTomorrow
                ) {
                    viewModel.setDueDate(daysFromNow: 1)
                }
                QuickDatePill(
                    "Next Week",
                    icon: "calendar",
                    isSelected: viewModel.isNextWeek
                ) {
                    viewModel.setDueDate(daysFromNow: 7)
                }
            }
            .padding(.vertical, DS.Spacing.xs)

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

            recurrenceOptions
        }
    }

    @ViewBuilder
    private var recurrenceOptions: some View {
        Picker("Repeat", selection: $viewModel.recurrencePattern) {
            ForEach(RecurrencePattern.allCases, id: \.self) { pattern in
                Text(pattern.label).tag(pattern)
            }
        }

        if viewModel.recurrencePattern != .none {
            Stepper("Every \(viewModel.recurrenceInterval) \(viewModel.recurrenceIntervalUnit)", value: $viewModel.recurrenceInterval, in: 1...99)

            if viewModel.recurrencePattern == .weekly {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("On these days")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    WeekdayPicker(selectedDays: $viewModel.selectedRecurrenceDays)
                }
            }

            Toggle("End date", isOn: $viewModel.hasRecurrenceEndDate)

            if viewModel.hasRecurrenceEndDate {
                DatePicker(
                    "Ends on",
                    selection: Binding(
                        get: { viewModel.recurrenceEndDate ?? Date().addingTimeInterval(86400 * 30) },
                        set: { viewModel.recurrenceEndDate = $0 }
                    ),
                    in: viewModel.dueDate...,
                    displayedComponents: [.date]
                )
            }
        }
    }

    private var prioritySection: some View {
        Section("Priority") {
            PriorityPicker(selected: $viewModel.selectedPriority)
                .padding(.vertical, DS.Spacing.xs)
        }
    }

    private var starredSection: some View {
        Section {
            StarredRow(isStarred: $viewModel.isStarred)
        }
    }

    private var tagsSection: some View {
        Section("Tags") {
            TagPickerView(
                selectedTagIds: $viewModel.selectedTagIds,
                availableTags: viewModel.availableTags,
                onCreateTag: { showingCreateTag = true }
            )
        }
    }

    private var colorSection: some View {
        Section("Color (optional)") {
            TaskColorPicker(selected: $viewModel.selectedColor)
                .padding(.vertical, DS.Spacing.sm)
        }
    }
}
