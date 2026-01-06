import Foundation
import SwiftUI

// MARK: - User

struct UserDTO: Codable, Identifiable, Hashable {
    let id: Int
    let email: String
    let name: String
    let role: String
    let timezone: String?
    let hasPassword: Bool?
    
    enum CodingKeys: String, CodingKey {
            case id, email, name, role, timezone
            case hasPassword = "has_password"
        }
}

// MARK: - List

struct ListDTO: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let description: String?
    let visibility: String
    let color: String?
    let role: String?
    let tasks_count: Int?
    let created_at: String?
    let updated_at: String?
    
    var listColor: Color {
        switch color ?? "blue" {
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
}

struct ListsResponse: Codable {
    let lists: [ListDTO]
    let tombstones: [String]?
}

// MARK: - Task
// MARK: - Priority

enum TaskPriority: Int, Codable, CaseIterable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3
    case urgent = 4
    
    var label: String {
        switch self {
        case .none: return "None"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
    
    var icon: String? {
        switch self {
        case .urgent: return "flag.fill"
        case .high: return "exclamationmark.3"
        case .medium: return "exclamationmark.2"
        case .low: return "exclamationmark"
        case .none: return nil
        }
    }
    
    var color: Color {
        switch self {
        case .urgent: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .gray
        case .none: return .clear
        }
    }
}

struct TaskDTO: Codable, Identifiable {
    let id: Int
    let list_id: Int
    let color: String?
    let title: String
    let note: String?
    let due_at: String?
    let completed_at: String?
    let priority: Int?
    let starred: Bool?
    let position: Int?
    let status: String?
    let can_edit: Bool?
    let can_delete: Bool?
    let created_at: String?
    let updated_at: String?
    
    let overdue: Bool?
    let minutes_overdue: Int?
    let requires_explanation_if_missed: Bool?
    let missed_reason: String?
    let missed_reason_submitted_at: String?

    var isCompleted: Bool {
        completed_at != nil
    }
    
    var isOverdue: Bool {
        overdue ?? false
    }
    
    var isStarred: Bool {
        starred ?? false
    }
    
    var needsReason: Bool {
        isOverdue && (requires_explanation_if_missed ?? false) && missed_reason == nil
    }

    var dueDate: Date? {
        guard let due_at else { return nil }
        return ISO8601DateFormatter().date(from: due_at)
    }
    var taskPriority: TaskPriority {
        TaskPriority(rawValue: priority ?? 0) ?? .none
    }
    
    var taskColor: Color {
        switch color {
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
    
    var isAnytime: Bool {
        guard let dueDate = dueDate else { return false }
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: dueDate)
        let minute = calendar.component(.minute, from: dueDate)
        return hour == 0 && minute == 0
    }

    var isActuallyOverdue: Bool {
        guard let dueDate = dueDate, !isCompleted else { return false }
        
        // Anytime tasks are only overdue after end of day
        if isAnytime {
            let calendar = Calendar.current
            let endOfDueDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: dueDate) ?? dueDate
            return Date() > endOfDueDay
        }
        
        return dueDate < Date()
    }
}

struct TasksResponse: Codable {
    let tasks: [TaskDTO]
    let tombstones: [String]?
}


// MARK: - Today

struct TodayResponse: Codable {
    let overdue: [TaskDTO]
    let due_today: [TaskDTO]
    let completed_today: [TaskDTO]
    let stats: TodayStats
    let streak: StreakInfo?
}

struct TodayStats: Codable {
    let overdue_count: Int
    let due_today_count: Int
    let completed_today_count: Int
}

struct StreakInfo: Codable {
    let current: Int
    let longest: Int
}

// MARK: - Sharing

struct ListShare: Codable, Identifiable {
    let id: Int
    let list_id: Int
    let user_id: Int?
    let role: String
    let user: UserDTO?
    let created_at: String?
    let updated_at: String?
}

struct ShareListRequest: Codable {
    let email: String
    let role: String
}

struct ShareListResponse: Codable {
    let id: Int
    let list_id: Int
    let role: String
    let user: UserDTO?
}

// MARK: - Membership

struct MembershipDTO: Codable, Identifiable {
    let id: Int
    let user: MemberUser
    let role: String
    let created_at: String?
    let updated_at: String?
    
    var isEditor: Bool {
        role == "editor"
    }
}

struct MemberUser: Codable {
    let id: Int
    let email: String?
    let name: String?
}

struct MembershipsResponse: Codable {
    let memberships: [MembershipDTO]
}

struct CreateMembershipRequest: Codable {
    let membership: MembershipParams
}

struct MembershipParams: Codable {
    let user_identifier: String
    let role: String
}

struct MembershipResponse: Codable {
    let membership: MembershipDTO
}
