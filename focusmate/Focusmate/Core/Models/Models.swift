import Foundation
import SwiftUI

// MARK: - User

struct UserDTO: Codable, Identifiable, Hashable {
    let id: Int
    let email: String
    let name: String
    let role: String
    let timezone: String?
}

// MARK: - List

struct ListDTO: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let description: String?
    let visibility: String
    let role: String?
    let tasks_count: Int?
    let created_at: String?
    let updated_at: String?
}

struct ListsResponse: Codable {
    let lists: [ListDTO]
    let tombstones: [String]?
}

// MARK: - Task

struct TaskDTO: Codable, Identifiable {
    let id: Int
    let list_id: Int
    let title: String
    let note: String?
    let due_at: String?
    let completed_at: String?
    let priority: Int?
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
        
        var needsReason: Bool {
            isOverdue && (requires_explanation_if_missed ?? false) && missed_reason == nil
        }

        var dueDate: Date? {
            guard let due_at else { return nil }
            return ISO8601DateFormatter().date(from: due_at)
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
}

struct TodayStats: Codable {
    let overdue_count: Int
    let due_today_count: Int
    let completed_today_count: Int
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
