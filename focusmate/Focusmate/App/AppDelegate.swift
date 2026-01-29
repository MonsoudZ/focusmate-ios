import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    /// Stored push token to be registered with backend
    static var pushToken: String?

    /// Buffer notification route for cold-start races (notification tapped before SwiftUI subscribes)
    private static var pendingRoute: NotificationAction?

    static func flushPendingRouteIfAny() {
        guard let route = pendingRoute else { return }
        pendingRoute = nil

        switch route {
        case .openTask(let taskId):
            NotificationCenter.default.post(name: .openTask, object: nil, userInfo: ["taskId": taskId])
        case .openToday:
            NotificationCenter.default.post(name: .openToday, object: nil)
        case .openInvite(let code):
            NotificationCenter.default.post(name: .openInvite, object: nil, userInfo: ["code": code])
        }
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // MARK: - Push Notification Registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        Logger.info("APNs token received", category: .general)

        AppDelegate.pushToken = token
        NotificationCenter.default.post(name: .didReceivePushToken, object: nil, userInfo: ["token": token])
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Logger.error("Failed to register for remote notifications: \(error)", category: .general)
    }

    // MARK: - Notification Presentation

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        routeNotification(response)
        completionHandler()
    }

    // MARK: - Universal Links

    /// Pending invite code for cold-start URL handling
    static var pendingInviteCode: String?

    /// Handle universal links (focusmate.app/invite/:code)
    static func handleIncomingURL(_ url: URL) -> Bool {
        // Check for invite URL pattern
        // Supports: https://focusmate.app/invite/ABC123
        let pathComponents = url.pathComponents
        if pathComponents.count >= 3,
           pathComponents[1] == "invite",
           !pathComponents[2].isEmpty {
            let code = pathComponents[2]
            pendingInviteCode = code
            pendingRoute = .openInvite(code)
            flushPendingRouteIfAny()
            return true
        }

        return false
    }

    // MARK: - Routing

    private func routeNotification(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        let identifier = response.notification.request.identifier

        // Server push payload routing
        if let action = NotificationAction(userInfo: userInfo) {
            AppDelegate.pendingRoute = action
            AppDelegate.flushPendingRouteIfAny()
            return
        }

        // Local notification routing
        if let action = NotificationAction(localIdentifier: identifier) {
            AppDelegate.pendingRoute = action
            AppDelegate.flushPendingRouteIfAny()
            return
        }
    }
}

// MARK: - Notification Parsing (local to AppDelegate)

private enum NotificationAction {
    case openTask(Int)
    case openToday
    case openInvite(String)

    init?(userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return nil }

        switch type {
        case "nudge":
            if let taskId = userInfo["task_id"] as? Int {
                self = .openTask(taskId)
            } else if let taskIdString = userInfo["task_id"] as? String, let taskId = Int(taskIdString) {
                self = .openTask(taskId)
            } else {
                return nil
            }
        default:
            return nil
        }
    }

    init?(localIdentifier: String) {
        if localIdentifier == "morning-briefing" {
            self = .openToday
            return
        }

        if localIdentifier.hasPrefix("task-") {
            let parts = localIdentifier.split(separator: "-")
            if parts.count >= 2, let taskId = Int(parts[1]) {
                self = .openTask(taskId)
                return
            }
        }

        return nil
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openTask = Notification.Name("openTask")
    static let openToday = Notification.Name("openToday")
    static let openInvite = Notification.Name("openInvite")
    static let didReceivePushToken = Notification.Name("didReceivePushToken")
}
