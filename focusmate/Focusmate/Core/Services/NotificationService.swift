import Combine
import Foundation
import UIKit
import UserNotifications

@MainActor
class NotificationService: ObservableObject {
  @Published var isAuthorized = false
  @Published var pushToken: String?

  private let center = UNUserNotificationCenter.current()

  init() {
    self.checkAuthorizationStatus()
  }

  // MARK: - Permission Management

  func requestPermissions() async -> Bool {
    do {
      let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
      self.isAuthorized = granted

      if granted {
        await self.registerForRemoteNotifications()
        #if DEBUG
        print("✅ NotificationService: Push permissions granted")
        #endif
      } else {
        #if DEBUG
        print("❌ NotificationService: Push permissions denied")
        #endif
      }

      return granted
    } catch {
      #if DEBUG
      print("❌ NotificationService: Failed to request permissions: \(error)")
      #endif
      return false
    }
  }

  private func checkAuthorizationStatus() {
    self.center.getNotificationSettings { [weak self] settings in
      DispatchQueue.main.async {
        self?.isAuthorized = settings.authorizationStatus == .authorized
      }
    }
  }

  // MARK: - Device Registration

  private func registerForRemoteNotifications() async {
    UIApplication.shared.registerForRemoteNotifications()
  }

  func setPushToken(_ token: String) {
    self.pushToken = token
    #if DEBUG
    print("🔔 NotificationService: Push token received: \(token)")
    #endif
  }

  // MARK: - Local Notifications

  func scheduleTaskReminder(for task: Item, at date: Date) {
    let content = UNMutableNotificationContent()
    content.title = "Task Reminder"
    content.body = "Don't forget: \(task.title)"
    content.sound = .default
    content.userInfo = [
      "task_id": task.id,
      "list_id": task.list_id,
      "type": "task_reminder",
    ]

    let trigger = UNCalendarNotificationTrigger(
      dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date),
      repeats: false
    )

    let request = UNNotificationRequest(
      identifier: "task_\(task.id)_\(date.timeIntervalSince1970)",
      content: content,
      trigger: trigger
    )

    self.center.add(request) { error in
      if let error {
        #if DEBUG
        print("❌ NotificationService: Failed to schedule reminder: \(error)")
        #endif
      } else {
        #if DEBUG
        print("✅ NotificationService: Scheduled reminder for task \(task.id)")
        #endif
      }
    }
  }

  func cancelTaskReminder(for task: Item) {
    let identifier = "task_\(task.id)_"
    self.center.getPendingNotificationRequests { [weak self] requests in
      let taskRequests = requests.filter { $0.identifier.hasPrefix(identifier) }
      let identifiers = taskRequests.map(\.identifier)

      if !identifiers.isEmpty {
        self?.center.removePendingNotificationRequests(withIdentifiers: identifiers)
        #if DEBUG
        print("✅ NotificationService: Cancelled \(identifiers.count) reminders for task \(task.id)")
        #endif
      }
    }
  }

  // MARK: - Push Notification Handling

  func handleNotificationResponse(_ response: UNNotificationResponse) {
    let userInfo = response.notification.request.content.userInfo

    guard let taskId = userInfo["task_id"] as? Int,
          let listId = userInfo["list_id"] as? Int
    else {
      #if DEBUG
      print("❌ NotificationService: Invalid notification data")
      #endif
      return
    }

    #if DEBUG
    print("🔔 NotificationService: Opening task \(taskId) in list \(listId)")
    #endif

    // Post notification to open the task
    NotificationCenter.default.post(
      name: .openTaskFromNotification,
      object: nil,
      userInfo: [
        "task_id": taskId,
        "list_id": listId,
      ]
    )
  }

  // MARK: - Badge Management

  func updateBadgeCount(_ count: Int) {
    self.center.setBadgeCount(count) { error in
      if let error {
        #if DEBUG
        print("❌ NotificationService: Failed to set badge count: \(error)")
        #endif
      }
    }
  }

  func clearBadge() {
    self.center.setBadgeCount(0) { error in
      if let error {
        #if DEBUG
        print("❌ NotificationService: Failed to clear badge: \(error)")
        #endif
      }
    }
  }
}

// MARK: - Notification Names

extension Notification.Name {
  static let openTaskFromNotification = Notification.Name("openTaskFromNotification")
}
