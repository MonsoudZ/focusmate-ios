import Foundation
import SwiftUI

struct TagDTO: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let color: String?
    let tasks_count: Int?
    let created_at: String?

    var tagColor: Color {
        guard let color else { return .blue }

        // Check predefined colors first
        switch color.lowercased() {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "pink": return .pink
        case "teal": return .teal
        case "yellow": return .yellow
        case "gray", "grey": return .gray
        default: break
        }

        // Try to parse as hex color
        if color.hasPrefix("#") {
            return Color(hex: color) ?? .blue
        }

        return .blue
    }
}

struct TagsResponse: Codable {
    let tags: [TagDTO]
}
