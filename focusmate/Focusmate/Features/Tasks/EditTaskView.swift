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
    @State private var hasDueDate: Bool
    @State private var isLoading = false
    @State private var error: FocusmateError?

    init(listId: Int, task: TaskDTO, taskService: TaskService, onSave: (() -> Void)? = nil) {
        self.listId = listId
        self.task = task
        self.taskService = taskService
        self.onSave = onSave

        _title = State(initialValue: task.title)
        _note = State(initialValue: task.note ?? "")
        _hasDueDate = State(initialValue: task.due_at != nil)
        _dueDate = State(initialValue: task.dueDate ?? Date())
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
                            "Due Date",
                            selection: $dueDate,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
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
            .alert("Error", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                if let error = error {
                    Text(error.message)
                }
            }
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
                dueAt: hasDueDate ? dueDate.ISO8601Format() : nil
            )
            onSave?()
            dismiss()
        } catch let err as FocusmateError {
            error = err
        } catch {
            self.error = .custom("UPDATE_ERROR", error.localizedDescription)
        }
    }
}
