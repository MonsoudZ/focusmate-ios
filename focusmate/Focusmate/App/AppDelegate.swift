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

    // Re-register for remote notifications on every cold launch.
    // Apple can rotate the APNs device token at any time (OS updates,
    // token expiry). Without this, the backend holds a stale token and
    // pushes silently fail. The existing didRegisterForRemoteNotifications
    // handler will forward any new token to the backend via AppState.
    if AppSettings.shared.didRequestPushPermission {
      application.registerForRemoteNotifications()
    }

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
    self.routeNotification(response)
    completionHandler()
  }

  // MARK: - Routing

  private func routeNotification(_ response: UNNotificationResponse) {
    let userInfo = response.notification.request.content.userInfo
    let identifier = response.notification.request.identifier

    // Server push payload routing
    if let route = DeepLinkRoute(pushNotificationUserInfo: userInfo) {
      Task { @MainActor in
        AppRouter.shared.handleDeepLink(route)
      }
      return
    }

    // Local notification routing
    if let route = DeepLinkRoute(localNotificationIdentifier: identifier) {
      Task { @MainActor in
        AppRouter.shared.handleDeepLink(route)
      }
      return
    }
  }
}

// MARK: - Notification Names

extension Notification.Name {
  static let didReceivePushToken = Notification.Name("didReceivePushToken")
}
