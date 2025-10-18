import UIKit
import UserNotifications

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // Handle notification launch
        if let notificationResponse = connectionOptions.notificationResponse {
            handleNotificationLaunch(notificationResponse)
        }
    }
    
    private func handleNotificationLaunch(_ response: UNNotificationResponse) {
        print("🔔 SceneDelegate: App launched from notification")
        // The NotificationDelegate will handle the actual task opening
    }
}

// MARK: - Push Token Registration

extension SceneDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("🔔 SceneDelegate: Device token received")
        NotificationDelegate.shared.handlePushToken(deviceToken)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ SceneDelegate: Failed to register for remote notifications")
        NotificationDelegate.shared.handlePushTokenError(error)
    }
}
