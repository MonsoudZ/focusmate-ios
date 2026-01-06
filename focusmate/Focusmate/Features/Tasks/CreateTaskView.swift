import SwiftUI

struct CreateTaskView: View {
    let listId: Int
    let taskService: TaskService
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var note = ""
    @State private var dueDate = Date()
    @State private var dueTime = Date()
    @State private var hasDueDate = false
    @State private var hasSpecificTime = false
    @State private var selectedColor: String? = nil
    @State private var selectedPriority: TaskPriority = .none
    @State private var isStarred = false
    @State private var isLoading = false
    @State private var error: FocusmateError?
    
    private let colors = ["blue", "green", "orange", "red", "purple", "pink", "teal", "yellow", "gray"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    TextField("Title", text: $title)

                    TextField("Notes (Optional)", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Due Date") {
                    Toggle("Set due date", isOn: $hasDueDate)

                    if hasDueDate {
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
                
                Section("Color (Optional)") {
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
            .onAppear {
                // Default time to 5pm
                let calendar = Calendar.current
                dueTime = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
            }
            .onChange(of: dueDate) { oldValue, newValue in
                // If today is selected and time is in the past, reset to now
                if Calendar.current.isDateInToday(newValue) && hasSpecificTime && dueTime < Date() {
                    dueTime = Date()
                }
            }
            .onChange(of: hasSpecificTime) { oldValue, newValue in
                // When enabling specific time on today, ensure time is not in past
                if newValue && Calendar.current.isDateInToday(dueDate) && dueTime < Date() {
                    dueTime = Date()
                }
            }
        }
    }
    
    private var finalDueDate: Date? {
        guard hasDueDate else { return nil }
        
        let calendar = Calendar.current
        
        if hasSpecificTime {
            // Combine date and time
            let timeComponents = calendar.dateComponents([.hour, .minute], from: dueTime)
            return calendar.date(bySettingHour: timeComponents.hour ?? 17,
                                  minute: timeComponents.minute ?? 0,
                                  second: 0,
                                  of: dueDate)
        } else {
            // Set to midnight (00:00) for "anytime" tasks
            return calendar.startOfDay(for: dueDate)
        }
    }
    
    private var minimumTime: Date {
        if Calendar.current.isDateInToday(dueDate) {
            return Date()
        }
        return Calendar.current.startOfDay(for: dueDate)
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
                starred: isStarred
            )
            HapticManager.success()
            dismiss()
        } catch let err as FocusmateError {
            error = err
            HapticManager.error()
        } catch {
            self.error = .custom("CREATE_ERROR", error.localizedDescription)
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
