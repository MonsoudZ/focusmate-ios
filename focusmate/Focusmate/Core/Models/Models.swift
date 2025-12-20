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

struct ListDTO: Codable, Identifiable {
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

    var isCompleted: Bool {
        completed_at != nil
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
