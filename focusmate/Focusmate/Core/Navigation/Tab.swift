import Foundation

/// Represents the main tabs in the app
enum Tab: Int, CaseIterable, Identifiable, Hashable {
    case today = 0
    case lists = 1
    case settings = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .lists: return "Lists"
        case .settings: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .today: return "sun.max.fill"
        case .lists: return "list.bullet"
        case .settings: return "person.circle"
        }
    }
}
