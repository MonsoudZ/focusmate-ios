import SwiftUI

struct CreateTaskView: View {
    let listId: Int
    let taskService: TaskService
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var note = ""
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
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
                               QuickDateButton(title: "Today", isSelected: isToday) {
                                   dueDate = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
                               }
                               QuickDateButton(title: "Tomorrow", isSelected: isTomorrow) {
                                   dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()) ?? Date()
                               }
                               QuickDateButton(title: "Next Week", isSelected: isNextWeek) {
                                   dueDate = Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()) ?? Date()
                               }
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
    
    struct QuickDateButton: View {
        let title: String
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(DesignSystem.Typography.caption1)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.secondaryBackground)
                    .foregroundColor(isSelected ? .white : DesignSystem.Colors.textPrimary)
                    .cornerRadius(DesignSystem.CornerRadius.sm)
            }
        }
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(dueDate)
    }

    private var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(dueDate)
    }

    private var isNextWeek: Bool {
        guard let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date()) else { return false }
        return Calendar.current.isDate(dueDate, inSameDayAs: nextWeek)
    }
}
