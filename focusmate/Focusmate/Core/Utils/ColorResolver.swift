import SwiftUI

/// Resolves a color string from the API into a SwiftUI Color.
///
/// ## Why this exists
/// Three DTOs (TaskDTO, ListDTO, TagDTO) each had their own color-string-to-Color
/// switch statement. TagDTO had the most complete version (case-insensitive matching
/// + hex fallback), while TaskDTO and ListDTO were missing both features — meaning
/// a hex color or "Blue" from the API would silently fall through to `.blue` default
/// in those DTOs but work correctly in TagDTO.
///
/// ## What this changes
/// Single code path for all color resolution, with the TagDTO behavior (case-insensitive
/// + hex) applied everywhere.
///
/// ## Tradeoff
/// All three DTOs now share the same default color (.blue). If a DTO ever needs a
/// different default, you'd pass it as a parameter rather than forking the switch.
enum ColorResolver {
    static func resolve(_ colorString: String?) -> Color {
        guard let color = colorString?.lowercased() else { return .blue }

        switch color {
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

        if color.hasPrefix("#") {
            return Color(hex: color) ?? .blue
        }

        return .blue
    }
}
