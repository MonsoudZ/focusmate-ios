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

  /// Materialized at init time from `due_at`. ISO8601 parsing costs ~0.1ms per
  /// call; with 100 tasks × 3+ accesses per render cycle the old computed
  /// property burned ~30ms/frame. Storing the parsed result moves the cost to
  /// the decode boundary (once) instead of every property access (hundreds of
  /// times per frame).
  let dueDate: Date?

  // MARK: - CodingKeys

  // dueDate is intentionally excluded — it's derived from due_at at init time,
  // not a wire-format field. Excluding it keeps encode/decode symmetrical with
  // the server contract.
  private enum CodingKeys: String, CodingKey {
    case id, list_id, list_name, color, title, note, due_at, completed_at
    case priority, starred, hidden, position, status, can_edit, can_delete
    case created_at, updated_at, tags, reschedule_events, parent_task_id
    case subtasks, creator
    case is_recurring, recurrence_pattern, recurrence_interval, recurrence_days
    case recurrence_end_date, recurrence_count, template_id, instance_date, instance_number
    case location_based, location_name, location_latitude, location_longitude
    case location_radius_meters, notify_on_arrival, notify_on_departure
    case notification_interval_minutes
    case has_subtasks, subtasks_count, subtasks_completed_count, subtask_completion_percentage
    case overdue, minutes_overdue, requires_explanation_if_missed
    case missed_reason, missed_reason_submitted_at
  }

  // MARK: - Memberwise Init

  // Swift suppresses the auto-synthesized memberwise init once we define
  // init(from:). This explicit init preserves the same call-site signature
  // that TestFactories and any other direct constructors rely on, while
  // computing dueDate from due_at so callers never pass it.
  init(
    id: Int,
    list_id: Int,
    list_name: String? = nil,
    color: String? = nil,
    title: String,
    note: String? = nil,
    due_at: String? = nil,
    completed_at: String? = nil,
    priority: Int? = nil,
    starred: Bool? = nil,
    hidden: Bool? = nil,
    position: Int? = nil,
    status: String? = nil,
    can_edit: Bool? = nil,
    can_delete: Bool? = nil,
    created_at: String? = nil,
    updated_at: String? = nil,
    tags: [TagDTO]? = nil,
    reschedule_events: [RescheduleEventDTO]? = nil,
    parent_task_id: Int? = nil,
    subtasks: [SubtaskDTO]? = nil,
    creator: TaskCreatorDTO? = nil,
    is_recurring: Bool? = nil,
    recurrence_pattern: String? = nil,
    recurrence_interval: Int? = nil,
    recurrence_days: [Int]? = nil,
    recurrence_end_date: String? = nil,
    recurrence_count: Int? = nil,
    template_id: Int? = nil,
    instance_date: String? = nil,
    instance_number: Int? = nil,
    location_based: Bool? = nil,
    location_name: String? = nil,
    location_latitude: Double? = nil,
    location_longitude: Double? = nil,
    location_radius_meters: Int? = nil,
    notify_on_arrival: Bool? = nil,
    notify_on_departure: Bool? = nil,
    notification_interval_minutes: Int? = nil,
    has_subtasks: Bool? = nil,
    subtasks_count: Int? = nil,
    subtasks_completed_count: Int? = nil,
    subtask_completion_percentage: Int? = nil,
    overdue: Bool? = nil,
    minutes_overdue: Int? = nil,
    requires_explanation_if_missed: Bool? = nil,
    missed_reason: String? = nil,
    missed_reason_submitted_at: String? = nil
  ) {
    self.id = id
    self.list_id = list_id
    self.list_name = list_name
    self.color = color
    self.title = title
    self.note = note
    self.due_at = due_at
    self.completed_at = completed_at
    self.priority = priority
    self.starred = starred
    self.hidden = hidden
    self.position = position
    self.status = status
    self.can_edit = can_edit
    self.can_delete = can_delete
    self.created_at = created_at
    self.updated_at = updated_at
    self.tags = tags
    self.reschedule_events = reschedule_events
    self.parent_task_id = parent_task_id
    self.subtasks = subtasks
    self.creator = creator
    self.is_recurring = is_recurring
    self.recurrence_pattern = recurrence_pattern
    self.recurrence_interval = recurrence_interval
    self.recurrence_days = recurrence_days
    self.recurrence_end_date = recurrence_end_date
    self.recurrence_count = recurrence_count
    self.template_id = template_id
    self.instance_date = instance_date
    self.instance_number = instance_number
    self.location_based = location_based
    self.location_name = location_name
    self.location_latitude = location_latitude
    self.location_longitude = location_longitude
    self.location_radius_meters = location_radius_meters
    self.notify_on_arrival = notify_on_arrival
    self.notify_on_departure = notify_on_departure
    self.notification_interval_minutes = notification_interval_minutes
    self.has_subtasks = has_subtasks
    self.subtasks_count = subtasks_count
    self.subtasks_completed_count = subtasks_completed_count
    self.subtask_completion_percentage = subtask_completion_percentage
    self.overdue = overdue
    self.minutes_overdue = minutes_overdue
    self.requires_explanation_if_missed = requires_explanation_if_missed
    self.missed_reason = missed_reason
    self.missed_reason_submitted_at = missed_reason_submitted_at
    self.dueDate = due_at.flatMap { ISO8601Utils.parseDate($0) }
  }

  // MARK: - Decodable

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try c.decode(Int.self, forKey: .id)
    self.list_id = try c.decode(Int.self, forKey: .list_id)
    self.list_name = try c.decodeIfPresent(String.self, forKey: .list_name)
    self.color = try c.decodeIfPresent(String.self, forKey: .color)
    self.title = try c.decode(String.self, forKey: .title)
    self.note = try c.decodeIfPresent(String.self, forKey: .note)
    self.due_at = try c.decodeIfPresent(String.self, forKey: .due_at)
    self.completed_at = try c.decodeIfPresent(String.self, forKey: .completed_at)
    self.priority = try c.decodeIfPresent(Int.self, forKey: .priority)
    self.starred = try c.decodeIfPresent(Bool.self, forKey: .starred)
    self.hidden = try c.decodeIfPresent(Bool.self, forKey: .hidden)
    self.position = try c.decodeIfPresent(Int.self, forKey: .position)
    self.status = try c.decodeIfPresent(String.self, forKey: .status)
    self.can_edit = try c.decodeIfPresent(Bool.self, forKey: .can_edit)
    self.can_delete = try c.decodeIfPresent(Bool.self, forKey: .can_delete)
    self.created_at = try c.decodeIfPresent(String.self, forKey: .created_at)
    self.updated_at = try c.decodeIfPresent(String.self, forKey: .updated_at)
    self.tags = try c.decodeIfPresent([TagDTO].self, forKey: .tags)
    self.reschedule_events = try c.decodeIfPresent([RescheduleEventDTO].self, forKey: .reschedule_events)
    self.parent_task_id = try c.decodeIfPresent(Int.self, forKey: .parent_task_id)
    self.subtasks = try c.decodeIfPresent([SubtaskDTO].self, forKey: .subtasks)
    self.creator = try c.decodeIfPresent(TaskCreatorDTO.self, forKey: .creator)
    self.is_recurring = try c.decodeIfPresent(Bool.self, forKey: .is_recurring)
    self.recurrence_pattern = try c.decodeIfPresent(String.self, forKey: .recurrence_pattern)
    self.recurrence_interval = try c.decodeIfPresent(Int.self, forKey: .recurrence_interval)
    self.recurrence_days = try c.decodeIfPresent([Int].self, forKey: .recurrence_days)
    self.recurrence_end_date = try c.decodeIfPresent(String.self, forKey: .recurrence_end_date)
    self.recurrence_count = try c.decodeIfPresent(Int.self, forKey: .recurrence_count)
    self.template_id = try c.decodeIfPresent(Int.self, forKey: .template_id)
    self.instance_date = try c.decodeIfPresent(String.self, forKey: .instance_date)
    self.instance_number = try c.decodeIfPresent(Int.self, forKey: .instance_number)
    self.location_based = try c.decodeIfPresent(Bool.self, forKey: .location_based)
    self.location_name = try c.decodeIfPresent(String.self, forKey: .location_name)
    self.location_latitude = try c.decodeIfPresent(Double.self, forKey: .location_latitude)
    self.location_longitude = try c.decodeIfPresent(Double.self, forKey: .location_longitude)
    self.location_radius_meters = try c.decodeIfPresent(Int.self, forKey: .location_radius_meters)
    self.notify_on_arrival = try c.decodeIfPresent(Bool.self, forKey: .notify_on_arrival)
    self.notify_on_departure = try c.decodeIfPresent(Bool.self, forKey: .notify_on_departure)
    self.notification_interval_minutes = try c.decodeIfPresent(Int.self, forKey: .notification_interval_minutes)
    self.has_subtasks = try c.decodeIfPresent(Bool.self, forKey: .has_subtasks)
    self.subtasks_count = try c.decodeIfPresent(Int.self, forKey: .subtasks_count)
    self.subtasks_completed_count = try c.decodeIfPresent(Int.self, forKey: .subtasks_completed_count)
    self.subtask_completion_percentage = try c.decodeIfPresent(Int.self, forKey: .subtask_completion_percentage)
    self.overdue = try c.decodeIfPresent(Bool.self, forKey: .overdue)
    self.minutes_overdue = try c.decodeIfPresent(Int.self, forKey: .minutes_overdue)
    self.requires_explanation_if_missed = try c.decodeIfPresent(Bool.self, forKey: .requires_explanation_if_missed)
    self.missed_reason = try c.decodeIfPresent(String.self, forKey: .missed_reason)
    self.missed_reason_submitted_at = try c.decodeIfPresent(String.self, forKey: .missed_reason_submitted_at)
    self.dueDate = self.due_at.flatMap { ISO8601Utils.parseDate($0) }
  }

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
