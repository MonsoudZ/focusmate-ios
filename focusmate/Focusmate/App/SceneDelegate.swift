import UIKit
import UserNotifications

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(_ scene: UIScene, willConnectTo _: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    guard scene is UIWindowScene else { return }

    // Handle notification launch
    if let notificationResponse = connectionOptions.notificationResponse {
      self.handleNotificationLaunch(notificationResponse)
    }
  }

  private func handleNotificationLaunch(_: UNNotificationResponse) {
    print("🔔 SceneDelegate: App launched from notification")
    // The NotificationDelegate will handle the actual task opening
  }
}

// MARK: - Push Token Registration

extension SceneDelegate {
  func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    print("🔔 SceneDelegate: Device token received")
    NotificationDelegate.shared.handlePushToken(deviceToken)
  }

  func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("❌ SceneDelegate: Failed to register for remote notifications")
    NotificationDelegate.shared.handlePushTokenError(error)
  }
}
