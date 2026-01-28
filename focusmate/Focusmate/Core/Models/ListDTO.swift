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
