import Foundation
import SwiftUI

enum TaskFormMode {
    case create(listId: Int)
    case edit(listId: Int, task: TaskDTO)
}

@MainActor
@Observable
final class TaskFormViewModel {
    let mode: TaskFormMode
    private let taskService: TaskService
    let tagService: TagService

    // MARK: - Shared Properties

    var title = ""
    var note = ""
    var dueDate = Date()
    var dueTime = Date()
    var hasSpecificTime = false
    var selectedColor: String?
    var selectedPriority: TaskPriority = .none
    var isStarred = false
    var selectedTagIds: Set<Int> = []
    var availableTags: [TagDTO] = []
    var isLoading = false
    var error: FocusmateError?

    // MARK: - Create-only Properties

    var recurrencePattern: RecurrencePattern = .none
    var recurrenceInterval = 1
    var selectedRecurrenceDays: Set<Int> = [1]
    var hasRecurrenceEndDate = false
    var recurrenceEndDate: Date?

    // MARK: - Edit-only Properties

    var hasDueDate = true
    let originalHadDueDate: Bool
    /// Snapshotted at form open: was the task overdue by 60+ minutes?
    private let wasSignificantlyOverdue: Bool

    // MARK: - Callbacks

    var onSave: (() -> Void)?
    var onDismiss: (() -> Void)?
    var onRescheduleRequired: ((Date, TaskDTO) -> Void)?

    // MARK: - Init

    init(mode: TaskFormMode, taskService: TaskService, tagService: TagService) {
        self.mode = mode
        self.taskService = taskService
        self.tagService = tagService

        switch mode {
        case .create:
            dueTime = Date.nextWholeHour()
            originalHadDueDate = false
            wasSignificantlyOverdue = false

        case .edit(_, let task):
            originalHadDueDate = task.due_at != nil
            wasSignificantlyOverdue = (task.minutes_overdue ?? 0) >= 60
            title = task.title
            note = task.note ?? ""
            hasDueDate = task.due_at != nil
            selectedColor = task.color
            selectedPriority = TaskPriority(rawValue: task.priority ?? 0) ?? .none
            isStarred = task.starred ?? false
            selectedTagIds = Set(task.tags?.map { $0.id } ?? [])

            if let existingDueDate = task.dueDate {
                dueDate = existingDueDate
                dueTime = existingDueDate
                let hour = Calendar.current.component(.hour, from: existingDueDate)
                let minute = Calendar.current.component(.minute, from: existingDueDate)
                hasSpecificTime = !(hour == 0 && minute == 0)
            } else {
                dueDate = Date()
                dueTime = Date.nextWholeHour()
                hasSpecificTime = false
            }
        }
    }

    // MARK: - Computed Properties (Shared)

    var isCreateMode: Bool {
        if case .create = mode { return true }
        return false
    }

    var listId: Int {
        switch mode {
        case .create(let listId): return listId
        case .edit(let listId, _): return listId
        }
    }

    var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    /// Whether saving should route through the reschedule flow.
    /// True when the task was overdue by 60+ minutes at form open AND the user changed the due date.
    var requiresReschedule: Bool {
        guard wasSignificantlyOverdue, case .edit(_, let task) = mode else { return false }
        return dueDateChanged(from: task)
    }

    private func dueDateChanged(from task: TaskDTO) -> Bool {
        guard let originalDue = task.dueDate else {
            // Had no due date, now adding one
            return hasDueDate
        }
        guard hasDueDate else {
            // Removing due date
            return true
        }
        guard let newDue = finalDueDate else { return false }
        // Compare with 60-second tolerance
        return abs(originalDue.timeIntervalSince(newDue)) > 60
    }

    var finalDueDate: Date? {
        if !isCreateMode && !hasDueDate { return nil }

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

    var minimumTime: Date {
        if Calendar.current.isDateInToday(dueDate) {
            return Date()
        }
        return Calendar.current.startOfDay(for: dueDate)
    }

    // MARK: - Create-only Computed

    var isToday: Bool {
        Calendar.current.isDateInToday(dueDate)
    }

    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(dueDate)
    }

    var isNextWeek: Bool {
        guard let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.startOfDay(for: Date())) else { return false }
        return Calendar.current.isDate(dueDate, inSameDayAs: nextWeek)
    }

    var recurrenceIntervalUnit: String {
        switch recurrencePattern {
        case .none: return ""
        case .daily: return recurrenceInterval == 1 ? "day" : "days"
        case .weekly: return recurrenceInterval == 1 ? "week" : "weeks"
        case .monthly: return recurrenceInterval == 1 ? "month" : "months"
        case .yearly: return recurrenceInterval == 1 ? "year" : "years"
        }
    }

    var isRecurring: Bool {
        recurrencePattern != .none
    }

    // MARK: - Methods

    func loadTags() async {
        do {
            availableTags = try await tagService.fetchTags()
        } catch {
            Logger.error("Failed to load tags: \(error)", category: .api)
        }
    }

    func setDueDate(daysFromNow: Int) {
        let calendar = Calendar.current
        let now = Date()

        if daysFromNow == 0 {
            dueDate = now
        } else {
            dueDate = calendar.date(byAdding: .day, value: daysFromNow, to: calendar.startOfDay(for: now)) ?? now
        }
    }

    func dueDateChanged() {
        if Calendar.current.isDateInToday(dueDate) && hasSpecificTime && dueTime < Date() {
            dueTime = Date()
        }
    }

    func hasSpecificTimeChanged() {
        if hasSpecificTime && Calendar.current.isDateInToday(dueDate) && dueTime < Date() {
            dueTime = Date()
        }
    }

    func submit() async {
        switch mode {
        case .create(let listId):
            await createTask(listId: listId)
        case .edit(let listId, let task):
            if requiresReschedule, let newDate = finalDueDate {
                onRescheduleRequired?(newDate, task)
                return
            }
            await updateTask(listId: listId, task: task)
        }
    }

    // MARK: - Private

    private func createTask(listId: Int) async {
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
            onDismiss?()
        } catch let err as FocusmateError {
            Logger.error("Failed to create task", error: err, category: .api)
            error = err
            HapticManager.error()
        } catch {
            Logger.error("Failed to create task", error: error, category: .api)
            self.error = ErrorHandler.shared.handle(error, context: "Creating task")
            HapticManager.error()
        }
    }

    private func updateTask(listId: Int, task: TaskDTO) async {
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
                starred: isStarred,
                tagIds: Array(selectedTagIds)
            )
            HapticManager.success()
            onSave?()
            onDismiss?()
        } catch let err as FocusmateError {
            Logger.error("Failed to update task", error: err, category: .api)
            error = err
            HapticManager.error()
        } catch {
            Logger.error("Failed to update task", error: error, category: .api)
            self.error = ErrorHandler.shared.handle(error, context: "Updating task")
            HapticManager.error()
        }
    }
}
