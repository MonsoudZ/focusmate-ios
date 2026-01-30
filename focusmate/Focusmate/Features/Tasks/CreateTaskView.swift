import SwiftUI

struct CreateTaskView: View {
    @Environment(\.dismiss) var dismiss

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
                Section("Task Details") {
                    TextField("Title *", text: $viewModel.title)

                    TextField("Notes (optional)", text: $viewModel.note, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Due Date *") {
                    HStack(spacing: DS.Spacing.sm) {
                        QuickDateButton("Today", isSelected: viewModel.isToday) {
                            viewModel.setDueDate(daysFromNow: 0)
                        }
                        QuickDateButton("Tomorrow", isSelected: viewModel.isTomorrow) {
                            viewModel.setDueDate(daysFromNow: 1)
                        }
                        QuickDateButton("Next Week", isSelected: viewModel.isNextWeek) {
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

                Section("Priority") {
                    Picker("Priority", selection: $viewModel.selectedPriority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            HStack {
                                if let icon = priority.icon {
                                    Image(systemName: icon)
                                        .foregroundStyle(priority.color)
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
                        Label("Starred", systemImage: DS.Icon.starFilled)
                            .foregroundStyle(.yellow)
                    }
                }

                Section("Tags") {
                    TagPickerView(
                        selectedTagIds: $viewModel.selectedTagIds,
                        availableTags: viewModel.availableTags,
                        onCreateTag: { showingCreateTag = true }
                    )
                }

                Section("Color (optional)") {
                    OptionalColorPicker(selected: $viewModel.selectedColor)
                        .padding(.vertical, DS.Spacing.sm)
                }
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
            .errorBanner($viewModel.error)
            .task {
                await viewModel.loadTags()
            }
            .onAppear {
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

// MARK: - Supporting Views

struct QuickDateButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    init(_ title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .tint(isSelected ? DS.Colors.accent : .gray)
    }
}

struct WeekdayPicker: View {
    @Binding var selectedDays: Set<Int>

    private let days = [(0, "S"), (1, "M"), (2, "T"), (3, "W"), (4, "T"), (5, "F"), (6, "S")]

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(days, id: \.0) { day, label in
                Button {
                    HapticManager.selection()
                    if selectedDays.contains(day) {
                        if selectedDays.count > 1 {
                            selectedDays.remove(day)
                        }
                    } else {
                        selectedDays.insert(day)
                    }
                } label: {
                    Text(label)
                        .font(.caption.bold())
                        .frame(width: 32, height: 32)
                        .background(selectedDays.contains(day) ? DS.Colors.accent : Color(.secondarySystemBackground))
                        .foregroundStyle(selectedDays.contains(day) ? .white : .primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct OptionalColorPicker: View {
    @Binding var selected: String?

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: DS.Spacing.md) {
            ForEach(DS.Colors.listColorOrder, id: \.self) { name in
                Circle()
                    .fill(DS.Colors.list(name))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(Color.primary, lineWidth: selected == name ? 3 : 0)
                    )
                    .onTapGesture {
                        HapticManager.selection()
                        selected = selected == name ? nil : name
                    }
            }
        }
    }
}

// MARK: - Recurrence Pattern Enum

enum RecurrencePattern: String, CaseIterable {
    case none = ""
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"

    var label: String {
        switch self {
        case .none: return "Never"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}
