import SwiftUI

struct CreateTaskView: View {
    let listId: Int
    let taskService: TaskService
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var note = ""
    @State private var dueDate = Date().addingTimeInterval(3600) // 1 hour from now
    @State private var hasDueDate = false
    @State private var isLoading = false
    @State private var error: FocusmateError?

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
                        // Quick options
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
                            "Due Date",
                            selection: $dueDate,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
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
            .alert("Error", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                if let error = error {
                    Text(error.message)
                }
            }
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
                dueAt: hasDueDate ? dueDate : nil
            )
            dismiss()
        } catch let err as FocusmateError {
            error = err
        } catch {
            self.error = .custom("CREATE_ERROR", error.localizedDescription)
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
            dueDate = now.addingTimeInterval(3600)
        } else {
            let targetDay = calendar.date(byAdding: .day, value: daysFromNow, to: calendar.startOfDay(for: now)) ?? now
            dueDate = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: targetDay) ?? targetDay
        }
    }
}
