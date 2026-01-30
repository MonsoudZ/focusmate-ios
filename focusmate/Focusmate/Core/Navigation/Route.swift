import Foundation

/// NavigationStack destination routes
enum Route: Hashable {
    // Lists tab routes
    case listDetail(ListDTO)
    case taskDetail(TaskDTO, listName: String)

    // Settings tab routes
    case notificationSettings
    case appBlockingSettings
}
