import Foundation
import UserNotifications
import UIKit

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    private override init() {
        super.init()
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .badge, .sound])
        } else {
            completionHandler([.alert, .badge, .sound])
        }
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        print("🔔 NotificationDelegate: Received notification response")
        print("🔔 UserInfo: \(userInfo)")
        
        // Handle different notification types
        if let taskId = userInfo["task_id"] as? Int,
           let listId = userInfo["list_id"] as? Int {
            
            print("🔔 Opening task \(taskId) in list \(listId)")
            
            // Post notification to open the task
            NotificationCenter.default.post(
                name: .openTaskFromNotification,
                object: nil,
                userInfo: [
                    "task_id": taskId,
                    "list_id": listId
                ]
            )
        }
        
        completionHandler()
    }
}

// MARK: - Push Token Handling

extension NotificationDelegate {
    func handlePushToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("🔔 NotificationDelegate: Push token received: \(token)")
        
        // Post notification with the token
        NotificationCenter.default.post(
            name: .pushTokenReceived,
            object: nil,
            userInfo: ["token": token]
        )
    }
    
    func handlePushTokenError(_ error: Error) {
        print("❌ NotificationDelegate: Failed to register for push notifications: \(error)")
    }
}
