import Foundation
import SwiftUI

struct ListOwnerDTO: Codable, Hashable, Sendable {
  let id: Int
  let name: String?
}

struct ListDTO: Codable, Identifiable, Hashable, Sendable {
  let id: Int
  let name: String
  let description: String?
  let visibility: String
  let color: String?
  let list_type: String?
  let user: ListOwnerDTO?
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
    ColorResolver.resolve(self.color)
  }

  var progress: Double {
    let total = self.parent_tasks_count ?? self.tasks_count ?? 0
    guard total > 0 else { return 0 }
    let completed = min(completed_tasks_count ?? 0, total)
    return Double(completed) / Double(total)
  }

  var hasOverdue: Bool {
    (self.overdue_tasks_count ?? 0) > 0
  }
}

struct ListMemberDTO: Codable, Identifiable, Hashable, Sendable {
  let id: Int
  let name: String?
  let email: String?
  let role: String?

  var displayName: String {
    self.name ?? self.email ?? "Member"
  }
}

struct ListResponse: Codable, Sendable {
  let list: ListDTO
}

struct ListsResponse: Codable, Sendable {
  let lists: [ListDTO]
  let tombstones: [String]?
}
