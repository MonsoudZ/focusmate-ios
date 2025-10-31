import Foundation
import SwiftUI

// MARK: - User Model

struct UserDTO: Codable, Identifiable, Hashable {
  let id: Int
  let email: String
  let name: String
  let role: String
  let timezone: String?

  var isCoach: Bool {
    role == "coach"
  }

  var isClient: Bool {
    role == "client" || role == "user"
  }
}

struct UserProfile: Codable {
  let id: Int
  let email: String
  let name: String
  let role: String
  let timezone: String
  let accessibleListsCount: Int
  let createdAt: String

  enum CodingKeys: String, CodingKey {
    case id, email, name, role, timezone
    case accessibleListsCount = "accessible_lists_count"
    case createdAt = "created_at"
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(Int.self, forKey: .id)
    self.email = try container.decode(String.self, forKey: .email)
    self.name = try container.decode(String.self, forKey: .name)
    self.role = try container.decode(String.self, forKey: .role)
    self.timezone = try container.decode(String.self, forKey: .timezone)
    self.accessibleListsCount = try container.decode(Int.self, forKey: .accessibleListsCount)
    self.createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
  }
}

struct ItemsResponse: Codable {
  let items: [Item]
}

// MARK: - List Model

struct ListDTO: Codable, Identifiable {
  let id: Int
  let name: String
  let description: String?
  let visibility: String
  let user_id: Int
  let deleted_at: String?
  let created_at: String
  let updated_at: String

  // Computed property for backward compatibility
  var title: String { name }
}

// MARK: - Coach Sharing Info

struct CoachShare: Codable, Identifiable {
  let id: Int
  let coach: UserDTO
  let permissions: [String] // ["view", "edit", "add_items"]

  enum CodingKeys: String, CodingKey {
    case id, coach, permissions
  }
}

// MARK: - Item Model

struct Item: Codable, Identifiable {
  let id: Int
  let list_id: Int
  let title: String
  let description: String?
  let due_at: String?
  let completed_at: String?
  let priority: Int
  let can_be_snoozed: Bool
  let notification_interval_minutes: Int
  let requires_explanation_if_missed: Bool

  // Status
  let overdue: Bool
  let minutes_overdue: Int
  let requires_explanation: Bool

  // Recurring
  let is_recurring: Bool
  let recurrence_pattern: String?
  let recurrence_interval: Int
  let recurrence_days: [Int]?

  // Location
  let location_based: Bool
  let location_name: String?
  let location_latitude: Double?
  let location_longitude: Double?
  let location_radius_meters: Int
  let notify_on_arrival: Bool
  let notify_on_departure: Bool

  // Accountability
  let missed_reason: String?
  let missed_reason_submitted_at: String?
  let missed_reason_reviewed_at: String?

  // Creator
  let creator: UserDTO
  let created_by_coach: Bool

  // Permissions
  let can_edit: Bool
  let can_delete: Bool
  let can_complete: Bool

  // Visibility
  let is_visible: Bool

  // Escalation
  let escalation: Escalation?

  // Subtasks
  let has_subtasks: Bool
  let subtasks_count: Int
  let subtasks_completed_count: Int
  let subtask_completion_percentage: Int

  // Timestamps
  let created_at: String
  let updated_at: String

  // Computed properties for SwiftUI
  var isCompleted: Bool {
    self.completed_at != nil
  }

  var priorityColor: String {
    switch self.priority {
    case 3: return "red"
    case 2: return "orange"
    case 1: return "yellow"
    default: return "gray"
    }
  }

  var priorityLabel: String {
    switch self.priority {
    case 3: return "Urgent"
    case 2: return "High"
    case 1: return "Medium"
    default: return "Low"
    }
  }

  var isStrict: Bool {
    !self.can_be_snoozed
  }

  var dueDate: Date? {
    guard let due_at else { return nil }
    let formatter = ISO8601DateFormatter()
    return formatter.date(from: due_at)
  }

  enum CodingKeys: String, CodingKey {
    case id, title, description, priority
    case list_id, due_at, completed_at
    case can_be_snoozed, notification_interval_minutes, requires_explanation_if_missed
    case overdue, minutes_overdue, requires_explanation
    case is_recurring, recurrence_pattern, recurrence_interval, recurrence_days
    case location_based, location_name, location_latitude, location_longitude, location_radius_meters
    case notify_on_arrival, notify_on_departure
    case missed_reason, missed_reason_submitted_at, missed_reason_reviewed_at
    case creator, created_by_coach
    case can_edit, can_delete, can_complete
    case is_visible = "visibility"
    case escalation, has_subtasks, subtasks_count, subtasks_completed_count, subtask_completion_percentage
    case created_at, updated_at
  }
}

// MARK: - Escalation Models

struct Escalation: Codable, Identifiable {
  let id: Int
  let level: String
  let notification_count: Int
  let blocking_app: Bool
  let coaches_notified: Bool
  let became_overdue_at: String?
  let last_notification_at: String?
}

// MARK: - Escalation Enums (for UI)

enum EscalationUrgency: String, Codable, CaseIterable {
  case low
  case medium
  case high
  case critical

  var displayName: String {
    rawValue.capitalized
  }
}

enum EscalationStatus: String, Codable {
  case open
  case resolved
  case dismissed
}

struct BlockingTask: Codable, Identifiable {
  let id: Int // Item ID
  let name: String
  let description: String?
  let dueDate: Date?
  let listId: Int
  let listName: String
  let escalationCount: Int
  let lastEscalatedAt: Date?
  let blockingReason: String? // The reason from the latest escalation

  enum CodingKeys: String, CodingKey {
    case id, name, description, dueDate
    case listId = "list_id"
    case listName = "list_name"
    case escalationCount = "escalation_count"
    case lastEscalatedAt = "last_escalated_at"
    case blockingReason = "blocking_reason"
  }
}

struct TaskExplanation: Codable, Identifiable {
  let id: Int
  let itemId: Int
  let userId: Int
  let explanationType: ExplanationType
  let notes: String?
  let createdAt: Date

  enum CodingKeys: String, CodingKey {
    case id, notes
    case itemId = "item_id"
    case userId = "user_id"
    case explanationType = "explanation_type"
    case createdAt = "created_at"
  }
}

enum ExplanationType: String, Codable, CaseIterable, Identifiable {
  case missedDeadline = "Missed Deadline"
  case blocked = "Blocked"
  case delayed = "Delayed"
  case reassigned = "Reassigned"
  case completedLate = "Completed Late"
  case other = "Other"

  var id: String { rawValue }

  var icon: String {
    switch self {
    case .missedDeadline: return "calendar.badge.minus"
    case .blocked: return "hand.raised.fill"
    case .delayed: return "hourglass"
    case .reassigned: return "person.2.fill"
    case .completedLate: return "checkmark.circle.fill"
    case .other: return "questionmark.circle"
    }
  }

  var color: Color {
    switch self {
    case .missedDeadline: return .red
    case .blocked: return .orange
    case .delayed: return .yellow
    case .reassigned: return .blue
    case .completedLate: return .green
    case .other: return .gray
    }
  }
}

// MARK: - Coaching Models

struct CoachingRelationship: Codable, Identifiable {
  let id: Int
  let coachId: Int
  let clientId: Int
  let status: String // e.g., "pending", "active", "ended"
  let createdAt: Date
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case id, status
    case coachId = "coach_id"
    case clientId = "client_id"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}

// MARK: - Location Model

struct Location: Codable, Identifiable {
  let id: Int
  let name: String
  let address: String?
  let latitude: Double
  let longitude: Double
  let createdAt: Date
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case id, name, address, latitude, longitude
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}

// MARK: - API Response Models

struct APIResponse<T: Decodable>: Decodable {
  let data: T
  let message: String?
}

struct EmptyAPIResponse: Decodable {}

// MARK: - Request Models (Legacy - kept for compatibility)

struct CreateItemRequest: Codable {
  let name: String
  let description: String?
  let dueDate: Date?
  let isVisible: Bool?

  enum CodingKeys: String, CodingKey {
    case name = "title" // Map 'name' to 'title' for Rails API
    case description
    case dueDate = "due_at"
    case isVisible = "is_visible"
  }
}

struct UpdateItemRequest: Codable {
  let name: String?
  let description: String?
  let completed: Bool?
  let dueDate: Date?
  let isVisible: Bool?

  enum CodingKeys: String, CodingKey {
    case name = "title" // Map 'name' to 'title' for Rails API
    case description, completed
    case dueDate = "due_at"
    case isVisible = "is_visible"
  }
}

// MARK: - List Sharing Models

struct ListShare: Codable, Identifiable {
  let id: Int
  let list_id: Int
  let user_id: Int
  let role: String // "viewer", "editor", "admin"
  let created_at: String
  let updated_at: String
  let user: UserDTO?

  var roleDisplayName: String {
    switch self.role {
    case "viewer": return "Viewer"
    case "editor": return "Editor"
    case "admin": return "Admin"
    default: return self.role.capitalized
    }
  }

  var roleColor: Color {
    switch self.role {
    case "viewer": return .blue
    case "editor": return .orange
    case "admin": return .red
    default: return .gray
    }
  }
}

struct ShareListRequest: Codable {
  let email: String
  let role: String
}

struct ShareListResponse: Codable {
  let id: Int
  let list_id: Int
  let email: String
  let role: String
  let status: String
  let invitation_token: String
  let user: UserDTO?
  let permissions: SharePermissions
  let invited_at: String
  let accepted_at: String?
  let created_at: String
  let updated_at: String
}

struct SharePermissions: Codable {
  let can_view: Bool
  let can_edit: Bool
  let can_add_items: Bool
  let can_delete_items: Bool
  let receive_notifications: Bool
}

// MARK: - Empty Response

struct EmptyResponse: Codable {}
