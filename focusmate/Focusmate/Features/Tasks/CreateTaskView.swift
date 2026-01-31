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

                Section("Color (optional)") {
                    TaskColorPicker(selected: $viewModel.selectedColor)
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
                // Auto-focus title field after a brief delay for smooth animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTitleFocused = true
                }
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

/// Modern pill-style quick date selector with icon
struct QuickDatePill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    init(_ title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button {
            HapticManager.selection()
            action()
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(DS.Typography.caption)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(isSelected ? DS.Colors.accent : Color(.tertiarySystemBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? DS.Colors.accent : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(DS.Anim.quick, value: isSelected)
    }
}

/// Horizontal visual priority picker
struct PriorityPicker: View {
    @Binding var selected: TaskPriority

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(TaskPriority.allCases, id: \.self) { priority in
                PriorityOption(
                    priority: priority,
                    isSelected: selected == priority
                ) {
                    HapticManager.selection()
                    selected = priority
                }
            }
        }
    }
}

struct PriorityOption: View {
    let priority: TaskPriority
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(isSelected ? priority.color.opacity(0.2) : Color(.tertiarySystemBackground))
                        .frame(width: 44, height: 44)

                    if let icon = priority.icon {
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundStyle(priority.color)
                    } else {
                        Image(systemName: "minus")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                }
                .overlay(
                    Circle()
                        .stroke(isSelected ? priority.color : Color.clear, lineWidth: 2)
                )
                .scaleEffect(isSelected ? 1.1 : 1.0)

                Text(priority.label)
                    .font(DS.Typography.caption)
                    .foregroundStyle(isSelected ? priority.color : .secondary)
            }
        }
        .buttonStyle(.plain)
        .animation(DS.Anim.quick, value: isSelected)
    }
}

/// Animated starred toggle row
struct StarredRow: View {
    @Binding var isStarred: Bool

    var body: some View {
        Button {
            HapticManager.selection()
            withAnimation(DS.Anim.quick) {
                isStarred.toggle()
            }
        } label: {
            HStack {
                Image(systemName: isStarred ? DS.Icon.starFilled : DS.Icon.star)
                    .font(.system(size: 22))
                    .foregroundStyle(isStarred ? .yellow : .secondary)
                    .scaleEffect(isStarred ? 1.2 : 1.0)
                    .animation(.spring(duration: 0.3, bounce: 0.5), value: isStarred)

                Text("Starred")
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)

                Spacer()

                if isStarred {
                    Text("Important")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Modern color picker with scale animation
struct TaskColorPicker: View {
    @Binding var selected: String?

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: DS.Spacing.md) {
            // "None" option
            Button {
                HapticManager.selection()
                selected = nil
            } label: {
                Circle()
                    .fill(Color(.tertiarySystemBackground))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    )
                    .overlay(
                        Circle()
                            .stroke(selected == nil ? DS.Colors.accent : Color.clear, lineWidth: 2)
                            .padding(-2)
                    )
                    .scaleEffect(selected == nil ? 1.1 : 1.0)
            }
            .buttonStyle(.plain)
            .animation(DS.Anim.quick, value: selected)

            ForEach(DS.Colors.listColorOrder, id: \.self) { name in
                Button {
                    HapticManager.selection()
                    selected = name
                } label: {
                    Circle()
                        .fill(DS.Colors.list(name))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(DS.Colors.accent, lineWidth: selected == name ? 2 : 0)
                                .padding(-2)
                        )
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .opacity(selected == name ? 1 : 0)
                        )
                        .scaleEffect(selected == name ? 1.1 : 1.0)
                }
                .buttonStyle(.plain)
                .animation(DS.Anim.quick, value: selected)
            }
        }
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
