import Foundation
import SwiftUI

// MARK: - User Model
struct UserDTO: Codable, Identifiable, Hashable {
    let id: Int
    let email: String
    let name: String?
    let role: String
    let timezone: String?
    let created_at: String?
    
    var isCoach: Bool {
        role == "coach"
    }
    
    var isClient: Bool {
        role == "client"
    }
}

// MARK: - List Model
struct ListDTO: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let owner: UserDTO
    let role: String  // "owner", "editor", or "viewer"
    let sharedWithCoaches: [CoachShare]
    let tasksCount: Int
    let overdueTasksCount: Int
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, owner, role
        case sharedWithCoaches = "shared_with_coaches"
        case tasksCount = "tasks_count"
        case overdueTasksCount = "overdue_tasks_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        owner = try container.decode(UserDTO.self, forKey: .owner)
        role = try container.decode(String.self, forKey: .role)
        sharedWithCoaches = try container.decodeIfPresent([CoachShare].self, forKey: .sharedWithCoaches) ?? []
        tasksCount = try container.decodeIfPresent(Int.self, forKey: .tasksCount) ?? 0
        overdueTasksCount = try container.decodeIfPresent(Int.self, forKey: .overdueTasksCount) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}

// MARK: - Coach Sharing Info
struct CoachShare: Codable, Identifiable {
    let id: Int
    let coach: UserDTO
    let permissions: [String]  // ["view", "edit", "add_items"]
    
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
        completed_at != nil
    }
    
    var priorityColor: String {
        switch priority {
        case 3: return "red"
        case 2: return "orange"
        case 1: return "yellow"
        default: return "gray"
        }
    }
    
    var priorityLabel: String {
        switch priority {
        case 3: return "Urgent"
        case 2: return "High"
        case 1: return "Medium"
        default: return "Low"
        }
    }
    
    var isStrict: Bool {
        !can_be_snoozed
    }
    
    var dueDate: Date? {
        guard let due_at = due_at else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: due_at)
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
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        rawValue.capitalized
    }
}

enum EscalationStatus: String, Codable {
    case open = "open"
    case resolved = "resolved"
    case dismissed = "dismissed"
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
    
    var id: String { self.rawValue }
    
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

// MARK: - Request Models
struct CreateListRequest: Codable {
    let name: String
    let description: String?
}

struct UpdateListRequest: Codable {
    let name: String?
    let description: String?
}

struct CreateItemRequest: Codable {
    let name: String
    let description: String?
    let dueDate: Date?
    let isVisible: Bool?
    
    enum CodingKeys: String, CodingKey {
        case name, description
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
        case name, description, completed
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
        switch role {
        case "viewer": return "Viewer"
        case "editor": return "Editor"
        case "admin": return "Admin"
        default: return role.capitalized
        }
    }
    
    var roleColor: Color {
        switch role {
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
