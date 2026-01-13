import SwiftUI

struct CreateTaskView: View {
    let listId: Int
    let taskService: TaskService
    let tagService: TagService
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var note = ""
    @State private var dueDate = Date()
    @State private var dueTime = Date()
    @State private var hasSpecificTime = false
    @State private var selectedColor: String? = nil
    @State private var selectedPriority: TaskPriority = .none
    @State private var isStarred = false
    @State private var selectedTagIds: Set<Int> = []
    @State private var availableTags: [TagDTO] = []
    @State private var showingCreateTag = false
    @State private var isLoading = false
    @State private var error: FocusmateError?
    
    // Recurrence state
    @State private var isRecurring = false
    @State private var recurrencePattern: RecurrencePattern = .none
    @State private var recurrenceInterval = 1
    @State private var selectedRecurrenceDays: Set<Int> = [1]
    @State private var recurrenceEndDate: Date? = nil
    @State private var hasRecurrenceEndDate = false
    
    private let colors = ["blue", "green", "orange", "red", "purple", "pink", "teal", "yellow", "gray"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    TextField("Title *", text: $title)

                    TextField("Notes (optional)", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Due Date *") {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Button("Today") {
                            setDueDate(daysFromNow: 0)
                        }
                        .buttonStyle(.bordered)
                        .tint(isToday ? DesignSystem.Colors.primary : .gray)
                        
                        Button("Tomorrow") {
                            setDueDate(daysFromNow: 1)
                        }
                        .buttonStyle(.bordered)
                        .tint(isTomorrow ? DesignSystem.Colors.primary : .gray)
                        
                        Button("Next Week") {
                            setDueDate(daysFromNow: 7)
                        }
                        .buttonStyle(.bordered)
                        .tint(isNextWeek ? DesignSystem.Colors.primary : .gray)
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)

                    DatePicker(
                        "Date",
                        selection: $dueDate,
                        in: Calendar.current.startOfDay(for: Date())...,
                        displayedComponents: [.date]
                    )
                    
                    Toggle("Specific time", isOn: $hasSpecificTime)
                    
                    if hasSpecificTime {
                        DatePicker(
                            "Time",
                            selection: $dueTime,
                            in: minimumTime...,
                            displayedComponents: [.hourAndMinute]
                        )
                    }
                    
                    Picker("Repeat", selection: $recurrencePattern) {
                        ForEach(RecurrencePattern.allCases, id: \.self) { pattern in
                            Text(pattern.label).tag(pattern)
                        }
                    }
                    
                    if recurrencePattern != .none {
                        Stepper("Every \(recurrenceInterval) \(recurrenceIntervalUnit)", value: $recurrenceInterval, in: 1...99)
                        
                        if recurrencePattern == .weekly {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("On these days")
                                    .font(DesignSystem.Typography.caption1)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                
                                HStack(spacing: 6) {
                                    ForEach([(0, "S"), (1, "M"), (2, "T"), (3, "W"), (4, "T"), (5, "F"), (6, "S")], id: \.0) { day, label in
                                        Button {
                                            HapticManager.selection()
                                            if selectedRecurrenceDays.contains(day) {
                                                if selectedRecurrenceDays.count > 1 {
                                                    selectedRecurrenceDays.remove(day)
                                                }
                                            } else {
                                                selectedRecurrenceDays.insert(day)
                                            }
                                        } label: {
                                            Text(label)
                                                .font(.caption.bold())
                                                .frame(width: 32, height: 32)
                                                .background(selectedRecurrenceDays.contains(day) ? DesignSystem.Colors.primary : DesignSystem.Colors.secondaryBackground)
                                                .foregroundColor(selectedRecurrenceDays.contains(day) ? .white : DesignSystem.Colors.textPrimary)
                                                .clipShape(Circle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        
                        Toggle("End date", isOn: $hasRecurrenceEndDate)
                        
                        if hasRecurrenceEndDate {
                            DatePicker(
                                "Ends on",
                                selection: Binding(
                                    get: { recurrenceEndDate ?? Date().addingTimeInterval(86400 * 30) },
                                    set: { recurrenceEndDate = $0 }
                                ),
                                in: dueDate...,
                                displayedComponents: [.date]
                            )
                        }
                    }
                }
                
                Section("Priority") {
                    Picker("Priority", selection: $selectedPriority) {
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
                    Toggle(isOn: $isStarred) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("Starred")
                        }
                    }
                }
                
                Section("Tags") {
                    TagPickerView(
                        selectedTagIds: $selectedTagIds,
                        availableTags: availableTags,
                        onCreateTag: { showingCreateTag = true }
                    )
                }
                
                Section("Color (optional)") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(colors, id: \.self) { color in
                            Circle()
                                .fill(colorFor(color))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
                                )
                                .onTapGesture {
                                    HapticManager.selection()
                                    if selectedColor == color {
                                        selectedColor = nil
                                    } else {
                                        selectedColor = color
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await createTask() }
                    }
                    .disabled(title.isEmpty || isLoading)
                }
            }
            .errorBanner($error)
            .task {
                await loadTags()
            }
            .onAppear {
                let calendar = Calendar.current
                dueTime = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
            }
            .onChange(of: dueDate) { oldValue, newValue in
                if Calendar.current.isDateInToday(newValue) && hasSpecificTime && dueTime < Date() {
                    dueTime = Date()
                }
            }
            .onChange(of: hasSpecificTime) { oldValue, newValue in
                if newValue && Calendar.current.isDateInToday(dueDate) && dueTime < Date() {
                    dueTime = Date()
                }
            }
            .onChange(of: recurrencePattern) { oldValue, newValue in
                isRecurring = newValue != .none
            }
            .sheet(isPresented: $showingCreateTag) {
                CreateTagView(tagService: tagService) {
                    Task { await loadTags() }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadTags() async {
        do {
            availableTags = try await tagService.fetchTags()
        } catch {
            Logger.error("Failed to load tags: \(error)", category: .api)
        }
    }
    
    private var finalDueDate: Date {
        let calendar = Calendar.current
        
        if hasSpecificTime {
            let timeComponents = calendar.dateComponents([.hour, .minute], from: dueTime)
            return calendar.date(bySettingHour: timeComponents.hour ?? 17,
                                  minute: timeComponents.minute ?? 0,
                                  second: 0,
                                  of: dueDate) ?? dueDate
        } else {
            return calendar.startOfDay(for: dueDate)
        }
    }
    
    private var minimumTime: Date {
        if Calendar.current.isDateInToday(dueDate) {
            return Date()
        }
        return Calendar.current.startOfDay(for: dueDate)
    }
    
    private var recurrenceIntervalUnit: String {
        switch recurrencePattern {
        case .none: return ""
        case .daily: return recurrenceInterval == 1 ? "day" : "days"
        case .weekly: return recurrenceInterval == 1 ? "week" : "weeks"
        case .monthly: return recurrenceInterval == 1 ? "month" : "months"
        case .yearly: return recurrenceInterval == 1 ? "year" : "years"
        }
    }
    
    private func colorFor(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "pink": return .pink
        case "teal": return .teal
        case "yellow": return .yellow
        case "gray": return .gray
        default: return .blue
        }
    }

    private func createTask() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await taskService.createTask(
                listId: listId,
                title: trimmedTitle,
                note: note.isEmpty ? nil : note,
                dueAt: finalDueDate,
                color: selectedColor,
                priority: selectedPriority,
                starred: isStarred,
                tagIds: Array(selectedTagIds),
                isRecurring: isRecurring,
                recurrencePattern: recurrencePattern == .none ? nil : recurrencePattern.rawValue,
                recurrenceInterval: isRecurring ? recurrenceInterval : nil,
                recurrenceDays: isRecurring && recurrencePattern == .weekly ? Array(selectedRecurrenceDays) : nil,
                recurrenceEndDate: hasRecurrenceEndDate ? recurrenceEndDate : nil,
                recurrenceCount: nil
            )
            HapticManager.success()
            dismiss()
        } catch let err as FocusmateError {
            error = err
            HapticManager.error()
        } catch {
            self.error = .custom("UNKNOWN", error.localizedDescription)
            HapticManager.error()
        }
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(dueDate)
    }

    private var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(dueDate)
    }

    private var isNextWeek: Bool {
        guard let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.startOfDay(for: Date())) else { return false }
        return Calendar.current.isDate(dueDate, inSameDayAs: nextWeek)
    }

    private func setDueDate(daysFromNow: Int) {
        let calendar = Calendar.current
        let now = Date()
        
        if daysFromNow == 0 {
            dueDate = now
        } else {
            dueDate = calendar.date(byAdding: .day, value: daysFromNow, to: calendar.startOfDay(for: now)) ?? now
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
