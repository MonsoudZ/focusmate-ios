import Foundation
import SwiftUI

struct TagDTO: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let color: String?
    let tasks_count: Int?
    let created_at: String?

    var tagColor: Color {
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
}

struct TagsResponse: Codable {
    let tags: [TagDTO]
}
