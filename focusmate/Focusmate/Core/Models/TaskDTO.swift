import Foundation
import SwiftUI

struct TaskCreatorDTO: Codable, Identifiable, Hashable {
  let id: Int
  let email: String?
  let name: String?
  let role: String?

  var displayName: String {
    self.name ?? self.email ?? "Member"
  }
}

struct TaskDTO: Codable, Identifiable {
  let id: Int
  let list_id: Int
  let list_name: String?
  let color: String?
  let title: String
  let note: String?
  let due_at: String?
  var completed_at: String?
  let priority: Int?
  var starred: Bool?
  var hidden: Bool?
  var position: Int?
  let status: String?
  let can_edit: Bool?
  let can_delete: Bool?
  let created_at: String?
  let updated_at: String?
  let tags: [TagDTO]?
  let reschedule_events: [RescheduleEventDTO]?
  let parent_task_id: Int?
  var subtasks: [SubtaskDTO]?
  let creator: TaskCreatorDTO?

  // Recurring fields
  let is_recurring: Bool?
  let recurrence_pattern: String?
  let recurrence_interval: Int?
  let recurrence_days: [Int]?
  let recurrence_end_date: String?
  let recurrence_count: Int?
  let template_id: Int?
  let instance_date: String?
  let instance_number: Int?

  // Location
  let location_based: Bool?
  let location_name: String?
  let location_latitude: Double?
  let location_longitude: Double?
  let location_radius_meters: Int?
  let notify_on_arrival: Bool?
  let notify_on_departure: Bool?

  /// Notification
  let notification_interval_minutes: Int?

  // Server-computed subtask metadata
  let has_subtasks: Bool?
  let subtasks_count: Int?
  let subtasks_completed_count: Int?
  let subtask_completion_percentage: Int?

  let overdue: Bool?
  let minutes_overdue: Int?
  let requires_explanation_if_missed: Bool?
  let missed_reason: String?
  let missed_reason_submitted_at: String?

  // MARK: - Computed Properties

  var isCompleted: Bool {
    self.completed_at != nil
  }

  var isOverdue: Bool {
    self.overdue ?? false
  }

  var isStarred: Bool {
    self.starred ?? false
  }

  var isHidden: Bool {
    self.hidden ?? false
  }

  var isRecurring: Bool {
    self.is_recurring ?? false
  }

  var isRecurringInstance: Bool {
    self.template_id != nil
  }

  var needsReason: Bool {
    self.isOverdue && (self.requires_explanation_if_missed ?? false) && self.missed_reason == nil
  }

  var hasBeenRescheduled: Bool {
    !(self.reschedule_events ?? []).isEmpty
  }

  var rescheduleCount: Int {
    self.reschedule_events?.count ?? 0
  }

  var dueDate: Date? {
    guard let due_at else { return nil }
    return ISO8601Utils.parseDate(due_at)
  }

  var taskPriority: TaskPriority {
    TaskPriority(rawValue: self.priority ?? 0) ?? .none
  }

  var taskColor: Color {
    ColorResolver.resolve(self.color)
  }

  var isAnytime: Bool {
    guard let dueDate else { return false }
    let calendar = Calendar.current
    let hour = calendar.component(.hour, from: dueDate)
    let minute = calendar.component(.minute, from: dueDate)
    return hour == 0 && minute == 0
  }

  var isActuallyOverdue: Bool {
    guard let dueDate, !isCompleted else { return false }

    let now = Date()

    if self.isAnytime {
      // "Anytime" tasks are due by end of the calendar day in the user's
      // local timezone.  Calendar.current uses the device timezone, which
      // matches the server's expectation (due_at is midnight user-tz).
      let calendar = Calendar.current
      guard let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: dueDate)) else {
        return false
      }
      return now >= startOfNextDay
    }

    return now > dueDate
  }

  var recurrenceDescription: String? {
    guard self.isRecurringInstance || self.isRecurring else { return nil }

    let interval = self.recurrence_interval ?? 1

    switch self.recurrence_pattern {
    case "daily":
      return interval == 1 ? "Daily" : "Every \(interval) days"
    case "weekly":
      if let days = recurrence_days, !days.isEmpty {
        let dayNames = days.compactMap { self.dayName(for: $0) }
        return interval == 1 ? "Weekly on \(dayNames.joined(separator: ", "))" : "Every \(interval) weeks"
      }
      return interval == 1 ? "Weekly" : "Every \(interval) weeks"
    case "monthly":
      return interval == 1 ? "Monthly" : "Every \(interval) months"
    case "yearly":
      return interval == 1 ? "Yearly" : "Every \(interval) years"
    default:
      return nil
    }
  }

  private func dayName(for day: Int) -> String? {
    switch day {
    case 0: return "Sun"
    case 1: return "Mon"
    case 2: return "Tue"
    case 3: return "Wed"
    case 4: return "Thu"
    case 5: return "Fri"
    case 6: return "Sat"
    default: return nil
    }
  }

  // MARK: - Subtask Helpers

  var hasSubtasks: Bool {
    guard let subtasks else { return false }
    return !subtasks.isEmpty
  }

  var subtaskCount: Int {
    self.subtasks?.count ?? 0
  }

  var completedSubtaskCount: Int {
    self.subtasks?.filter(\.isCompleted).count ?? 0
  }

  var subtaskProgress: String {
    "\(self.completedSubtaskCount)/\(self.subtaskCount)"
  }

  var isSubtask: Bool {
    self.parent_task_id != nil
  }
}

struct TasksResponse: Codable {
  let tasks: [TaskDTO]
  let tombstones: [String]?
}

struct SingleTaskResponse: Codable {
  let task: TaskDTO
}

// MARK: - Hashable Conformance

//
// TaskDTO is an entity — identity is the primary key.  Two DTOs with the
// same `id` represent the same task.  Change detection (title edited,
// completion toggled, etc.) is handled by the ViewModel's @Published
// properties, not by DTO equality.

extension TaskDTO: Hashable {
  static func == (lhs: TaskDTO, rhs: TaskDTO) -> Bool {
    lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(self.id)
  }
}
