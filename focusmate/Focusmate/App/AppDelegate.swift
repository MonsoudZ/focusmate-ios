import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
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
        let identifier = response.notification.request.identifier
        
        if identifier.hasPrefix("task-") {
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

extension Notification.Name {
    static let openTask = Notification.Name("openTask")
    static let openToday = Notification.Name("openToday")
}
