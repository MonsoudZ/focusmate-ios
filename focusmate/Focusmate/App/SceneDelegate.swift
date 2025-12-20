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
    Logger.debug("App launched from notification", category: .ui)
    // The NotificationDelegate will handle the actual task opening
  }
}

// MARK: - Push Token Registration

extension SceneDelegate {
  func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Logger.debug("Device token received", category: .ui)
    NotificationDelegate.shared.handlePushToken(deviceToken)
  }

  func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    Logger.error("Failed to register for remote notifications", error: error, category: .ui)
    NotificationDelegate.shared.handlePushTokenError(error)
  }
}
