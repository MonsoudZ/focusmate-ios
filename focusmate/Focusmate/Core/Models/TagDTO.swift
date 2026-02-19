import Foundation
import SwiftUI

struct TagDTO: Codable, Identifiable, Hashable {
  let id: Int
  let name: String
  let color: String?
  let tasks_count: Int?
  let created_at: String?

  var tagColor: Color {
    ColorResolver.resolve(self.color)
  }
}

struct TagsResponse: Codable {
  let tags: [TagDTO]
}
