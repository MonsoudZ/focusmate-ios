import Foundation
import SwiftUI

struct ListDTO: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let description: String?
    let visibility: String
    let color: String?
    let list_type: String?
    let role: String?
    let tasks_count: Int?
    let parent_tasks_count: Int?
    let completed_tasks_count: Int?
    let overdue_tasks_count: Int?
    let members: [ListMemberDTO]?
    let tags: [TagDTO]?
    let created_at: String?
    let updated_at: String?

    var listColor: Color {
        ColorResolver.resolve(color)
    }

    var progress: Double {
        let total = parent_tasks_count ?? tasks_count ?? 0
        guard total > 0 else { return 0 }
        let completed = completed_tasks_count ?? 0
        return Double(completed) / Double(total)
    }

    var hasOverdue: Bool {
        (overdue_tasks_count ?? 0) > 0
    }
}

struct ListMemberDTO: Codable, Identifiable, Hashable {
    let id: Int
    let name: String?
    let email: String
    let role: String?
}

struct ListResponse: Codable {
    let list: ListDTO
}

struct ListsResponse: Codable {
    let lists: [ListDTO]
    let tombstones: [String]?
}
