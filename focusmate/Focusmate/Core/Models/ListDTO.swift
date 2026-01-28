import Foundation
import SwiftUI

struct ListDTO: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let description: String?
    let visibility: String
    let color: String?
    let role: String?
    let tasks_count: Int?
    let parent_tasks_count: Int?
    let completed_tasks_count: Int?
    let overdue_tasks_count: Int?
    let members: [ListMemberDTO]?
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

struct ListsResponse: Codable {
    let lists: [ListDTO]
    let tombstones: [String]?
}
