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
      self.dueTime = Date.nextWholeHour()
      self.originalHadDueDate = false
      self.wasSignificantlyOverdue = false

    case let .edit(_, task):
      self.originalHadDueDate = task.due_at != nil
      self.wasSignificantlyOverdue = (task.minutes_overdue ?? 0) >= 60
      self.title = task.title
      self.note = task.note ?? ""
      self.hasDueDate = task.due_at != nil
      self.selectedColor = task.color
      self.selectedPriority = TaskPriority(rawValue: task.priority ?? 0) ?? .none
      self.isStarred = task.starred ?? false
      self.selectedTagIds = Set(task.tags?.map(\.id) ?? [])

      if let existingDueDate = task.dueDate {
        self.dueDate = existingDueDate
        self.dueTime = existingDueDate
        let hour = Calendar.current.component(.hour, from: existingDueDate)
        let minute = Calendar.current.component(.minute, from: existingDueDate)
        self.hasSpecificTime = !(hour == 0 && minute == 0)
      } else {
        self.dueDate = Date()
        self.dueTime = Date.nextWholeHour()
        self.hasSpecificTime = false
      }
    }
  }

  // MARK: - Computed Properties (Shared)

  var isCreateMode: Bool {
    if case .create = self.mode { return true }
    return false
  }

  var listId: Int {
    switch self.mode {
    case let .create(listId): return listId
    case let .edit(listId, _): return listId
    }
  }

  var canSubmit: Bool {
    !self.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !self.isLoading
  }

  /// Whether saving should route through the reschedule flow.
  /// True when the task was overdue by 60+ minutes at form open AND the user changed the due date.
  var requiresReschedule: Bool {
    guard self.wasSignificantlyOverdue, case let .edit(_, task) = mode else { return false }
    return self.dueDateChanged(from: task)
  }

  private func dueDateChanged(from task: TaskDTO) -> Bool {
    guard let originalDue = task.dueDate else {
      // Had no due date, now adding one
      return self.hasDueDate
    }
    guard self.hasDueDate else {
      // Removing due date
      return true
    }
    guard let newDue = finalDueDate else { return false }
    // Compare with 60-second tolerance
    return abs(originalDue.timeIntervalSince(newDue)) > 60
  }

  var finalDueDate: Date? {
    if !self.isCreateMode, !self.hasDueDate { return nil }

    let calendar = Calendar.current
    if self.hasSpecificTime {
      let timeComponents = calendar.dateComponents([.hour, .minute], from: self.dueTime)
      return calendar.date(bySettingHour: timeComponents.hour ?? 17,
                           minute: timeComponents.minute ?? 0,
                           second: 0,
                           of: self.dueDate) ?? self.dueDate
    } else {
      return calendar.startOfDay(for: self.dueDate)
    }
  }

  var minimumTime: Date {
    if Calendar.current.isDateInToday(self.dueDate) {
      return Date()
    }
    return Calendar.current.startOfDay(for: self.dueDate)
  }

  // MARK: - Create-only Computed

  var isToday: Bool {
    Calendar.current.isDateInToday(self.dueDate)
  }

  var isTomorrow: Bool {
    Calendar.current.isDateInTomorrow(self.dueDate)
  }

  var isNextWeek: Bool {
    guard let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.startOfDay(for: Date()))
    else { return false }
    return Calendar.current.isDate(self.dueDate, inSameDayAs: nextWeek)
  }

  var recurrenceIntervalUnit: String {
    switch self.recurrencePattern {
    case .none: return ""
    case .daily: return self.recurrenceInterval == 1 ? "day" : "days"
    case .weekly: return self.recurrenceInterval == 1 ? "week" : "weeks"
    case .monthly: return self.recurrenceInterval == 1 ? "month" : "months"
    case .yearly: return self.recurrenceInterval == 1 ? "year" : "years"
    }
  }

  var isRecurring: Bool {
    self.recurrencePattern != .none
  }

  // MARK: - Methods

  func loadTags() async {
    do {
      self.availableTags = try await self.tagService.fetchTags()
    } catch {
      Logger.error("Failed to load tags: \(error)", category: .api)
    }
  }

  func setDueDate(daysFromNow: Int) {
    let calendar = Calendar.current
    let now = Date()

    if daysFromNow == 0 {
      self.dueDate = now
    } else {
      self.dueDate = calendar.date(byAdding: .day, value: daysFromNow, to: calendar.startOfDay(for: now)) ?? now
    }
  }

  func dueDateChanged() {
    if Calendar.current.isDateInToday(self.dueDate), self.hasSpecificTime, self.dueTime < Date() {
      self.dueTime = Date()
    }
  }

  func hasSpecificTimeChanged() {
    if self.hasSpecificTime, Calendar.current.isDateInToday(self.dueDate), self.dueTime < Date() {
      self.dueTime = Date()
    }
  }

  func submit() async {
    switch self.mode {
    case let .create(listId):
      await self.createTask(listId: listId)
    case let .edit(listId, task):
      if self.requiresReschedule, let newDate = finalDueDate {
        self.onRescheduleRequired?(newDate, task)
        return
      }
      await self.updateTask(listId: listId, task: task)
    }
  }

  // MARK: - Private

  private func createTask(listId: Int) async {
    let trimmedTitle = self.title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty else { return }

    self.isLoading = true
    defer { isLoading = false }

    do {
      _ = try await self.taskService.createTask(
        listId: listId,
        title: trimmedTitle,
        note: self.note.isEmpty ? nil : self.note,
        dueAt: self.finalDueDate,
        color: self.selectedColor,
        priority: self.selectedPriority,
        starred: self.isStarred,
        tagIds: Array(self.selectedTagIds),
        isRecurring: self.isRecurring,
        recurrencePattern: self.recurrencePattern == .none ? nil : self.recurrencePattern.rawValue,
        recurrenceInterval: self.isRecurring ? self.recurrenceInterval : nil,
        recurrenceDays: self.isRecurring && self
          .recurrencePattern == .weekly ? Array(self.selectedRecurrenceDays) : nil,
        recurrenceEndDate: self.hasRecurrenceEndDate ? self.recurrenceEndDate : nil,
        recurrenceCount: nil
      )
      HapticManager.success()
      self.onDismiss?()
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
    let trimmedTitle = self.title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty else { return }

    self.isLoading = true
    defer { isLoading = false }

    do {
      _ = try await self.taskService.updateTask(
        listId: listId,
        taskId: task.id,
        title: trimmedTitle,
        note: self.note.isEmpty ? nil : self.note,
        dueAt: self.finalDueDate?.ISO8601Format(),
        color: self.selectedColor,
        priority: self.selectedPriority,
        starred: self.isStarred,
        tagIds: Array(self.selectedTagIds)
      )
      HapticManager.success()
      self.onSave?()
      self.onDismiss?()
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
