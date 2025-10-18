import Foundation
import UserNotifications
import UIKit
import Combine

@MainActor
class NotificationService: ObservableObject {
    @Published var isAuthorized = false
    @Published var pushToken: String?
    
    private let center = UNUserNotificationCenter.current()
    
    init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Permission Management
    
    func requestPermissions() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            
            if granted {
                await registerForRemoteNotifications()
                print("✅ NotificationService: Push permissions granted")
            } else {
                print("❌ NotificationService: Push permissions denied")
            }
            
            return granted
        } catch {
            print("❌ NotificationService: Failed to request permissions: \(error)")
            return false
        }
    }
    
    private func checkAuthorizationStatus() {
        center.getNotificationSettings { [weak self] settings in
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
        pushToken = token
        print("🔔 NotificationService: Push token received: \(token)")
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
            "type": "task_reminder"
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
        
        center.add(request) { error in
            if let error = error {
                print("❌ NotificationService: Failed to schedule reminder: \(error)")
            } else {
                print("✅ NotificationService: Scheduled reminder for task \(task.id)")
            }
        }
    }
    
    func cancelTaskReminder(for task: Item) {
        let identifier = "task_\(task.id)_"
        center.getPendingNotificationRequests { [weak self] requests in
            let taskRequests = requests.filter { $0.identifier.hasPrefix(identifier) }
            let identifiers = taskRequests.map { $0.identifier }
            
            if !identifiers.isEmpty {
                self?.center.removePendingNotificationRequests(withIdentifiers: identifiers)
                print("✅ NotificationService: Cancelled \(identifiers.count) reminders for task \(task.id)")
            }
        }
    }
    
    // MARK: - Push Notification Handling
    
    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        
        guard let taskId = userInfo["task_id"] as? Int,
              let listId = userInfo["list_id"] as? Int else {
            print("❌ NotificationService: Invalid notification data")
            return
        }
        
        print("🔔 NotificationService: Opening task \(taskId) in list \(listId)")
        
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
    
    // MARK: - Badge Management
    
    func updateBadgeCount(_ count: Int) {
        center.setBadgeCount(count) { error in
            if let error = error {
                print("❌ NotificationService: Failed to set badge count: \(error)")
            }
        }
    }
    
    func clearBadge() {
        center.setBadgeCount(0) { error in
            if let error = error {
                print("❌ NotificationService: Failed to clear badge: \(error)")
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openTaskFromNotification = Notification.Name("openTaskFromNotification")
}
