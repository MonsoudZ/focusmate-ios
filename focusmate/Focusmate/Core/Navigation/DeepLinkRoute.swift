import Foundation

/// Routes for deep links (push notifications and URLs)
enum DeepLinkRoute: Equatable {
    case openToday
    case openTask(taskId: Int)
    case openInvite(code: String)

    // MARK: - Parsing

    /// Parse from server push notification userInfo
    init?(pushNotificationUserInfo userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return nil }

        switch type {
        case "nudge":
            if let taskId = userInfo["task_id"] as? Int {
                self = .openTask(taskId: taskId)
            } else if let taskIdString = userInfo["task_id"] as? String, let taskId = Int(taskIdString) {
                self = .openTask(taskId: taskId)
            } else {
                return nil
            }
        default:
            return nil
        }
    }

    /// Parse from local notification identifier
    init?(localNotificationIdentifier identifier: String) {
        if identifier == "morning-briefing" {
            self = .openToday
            return
        }

        if identifier.hasPrefix("task-") {
            let parts = identifier.split(separator: "-")
            if parts.count >= 2, let taskId = Int(parts[1]) {
                self = .openTask(taskId: taskId)
                return
            }
        }

        return nil
    }

    /// Parse from URL (universal links)
    /// Supports: focusmate://invite/ABC123 or https://focusmate.app/invite/ABC123
    init?(url: URL) {
        let pathComponents = url.pathComponents

        // HTTPS universal links: https://focusmate.app/invite/CODE
        if pathComponents.count >= 3,
           pathComponents[1] == "invite",
           !pathComponents[2].isEmpty {
            self = .openInvite(code: pathComponents[2])
            return
        }

        // Custom scheme: focusmate://invite/CODE
        // URL parses "invite" as host, code lands in pathComponents[1]
        if url.host == "invite",
           pathComponents.count >= 2,
           !pathComponents[1].isEmpty {
            self = .openInvite(code: pathComponents[1])
            return
        }

        return nil
    }
}
