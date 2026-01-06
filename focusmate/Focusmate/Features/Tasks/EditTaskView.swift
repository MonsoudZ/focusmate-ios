import SwiftUI

struct EditTaskView: View {
    let listId: Int
    let task: TaskDTO
    let taskService: TaskService
    var onSave: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss

    @State private var title: String
    @State private var note: String
    @State private var dueDate: Date
    @State private var dueTime: Date
    @State private var hasDueDate: Bool
    @State private var hasSpecificTime: Bool
    @State private var selectedColor: String?
    @State private var selectedPriority: TaskPriority
    @State private var isStarred: Bool
    @State private var isLoading = false
    @State private var error: FocusmateError?
    
    private let colors = ["blue", "green", "orange", "red", "purple", "pink", "teal", "yellow", "gray"]

    init(listId: Int, task: TaskDTO, taskService: TaskService, onSave: (() -> Void)? = nil) {
        self.listId = listId
        self.task = task
        self.taskService = taskService
        self.onSave = onSave

        _title = State(initialValue: task.title)
        _note = State(initialValue: task.note ?? "")
        _hasDueDate = State(initialValue: task.due_at != nil)
        _selectedColor = State(initialValue: task.color)
        _selectedPriority = State(initialValue: TaskPriority(rawValue: task.priority ?? 0) ?? .none)
        _isStarred = State(initialValue: task.starred ?? false)
        
        // Parse existing due date
        if let existingDueDate = task.dueDate {
            _dueDate = State(initialValue: existingDueDate)
            _dueTime = State(initialValue: existingDueDate)
            
            // Check if it's midnight (anytime task)
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: existingDueDate)
            let minute = calendar.component(.minute, from: existingDueDate)
            _hasSpecificTime = State(initialValue: !(hour == 0 && minute == 0))
        } else {
            _dueDate = State(initialValue: Date())
            _dueTime = State(initialValue: Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date())
            _hasSpecificTime = State(initialValue: false)
        }
    }

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
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await updateTask() }
                    }
                    .disabled(title.isEmpty || isLoading)
                }
            }
            .errorBanner($error)
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
    
    private var minimumTime: Date {
        if Calendar.current.isDateInToday(dueDate) {
            return Date()
        }
        return Calendar.current.startOfDay(for: dueDate)
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

    private func updateTask() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await taskService.updateTask(
                listId: listId,
                taskId: task.id,
                title: trimmedTitle,
                note: note.isEmpty ? nil : note,
                dueAt: finalDueDate?.ISO8601Format(),
                color: selectedColor,
                priority: selectedPriority,
                starred: isStarred
            )
            HapticManager.success()
            onSave?()
            dismiss()
        } catch let err as FocusmateError {
            error = err
            HapticManager.error()
        } catch {
            self.error = .custom("UPDATE_ERROR", error.localizedDescription)
            HapticManager.error()
        }
    }
}
