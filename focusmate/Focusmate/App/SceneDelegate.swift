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
    #if DEBUG
    print("🔔 SceneDelegate: App launched from notification")
    #endif
    // The NotificationDelegate will handle the actual task opening
  }
}

// MARK: - Push Token Registration

extension SceneDelegate {
  func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    #if DEBUG
    print("🔔 SceneDelegate: Device token received")
    #endif
    NotificationDelegate.shared.handlePushToken(deviceToken)
  }

  func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    #if DEBUG
    print("❌ SceneDelegate: Failed to register for remote notifications")
    #endif
    NotificationDelegate.shared.handlePushTokenError(error)
  }
}
