import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    /// Stored push token to be registered with backend
    static var pushToken: String?
    
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
        Logger.info("APNs token received: \(token.prefix(20))...", category: .general)
        
        // Store token and post notification
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
    
    // Show notification banner even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let identifier = response.notification.request.identifier
        
        // Handle push notification data (from server)
        if let type = userInfo["type"] as? String {
            switch type {
            case "nudge":
                if let taskId = userInfo["task_id"] as? Int {
                    NotificationCenter.default.post(
                        name: .openTask,
                        object: nil,
                        userInfo: ["taskId": taskId]
                    )
                }
            default:
                break
            }
        }
        // Handle local notification identifiers
        else if identifier.hasPrefix("task-") {
            let parts = identifier.split(separator: "-")
            if parts.count >= 2, let taskId = Int(parts[1]) {
                NotificationCenter.default.post(
                    name: .openTask,
                    object: nil,
                    userInfo: ["taskId": taskId]
                )
            }
        } else if identifier == "morning-briefing" {
            NotificationCenter.default.post(name: .openToday, object: nil)
        }
        
        completionHandler()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openTask = Notification.Name("openTask")
    static let openToday = Notification.Name("openToday")
    static let didReceivePushToken = Notification.Name("didReceivePushToken")
}
