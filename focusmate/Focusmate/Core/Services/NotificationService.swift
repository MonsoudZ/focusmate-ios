import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    
    private init() {}
    
    // MARK: - Preferences
    
    private var dueSoonEnabled: Bool {
        UserDefaults.standard.object(forKey: "dueSoonReminders") as? Bool ?? true
    }
    
    private var overdueEnabled: Bool {
        UserDefaults.standard.object(forKey: "overdueAlerts") as? Bool ?? true
    }
    
    private var morningBriefingEnabled: Bool {
        UserDefaults.standard.object(forKey: "morningBriefing") as? Bool ?? true
    }
    
    // MARK: - Permission
    
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            Logger.info("Notification permission: \(granted ? "granted" : "denied")", category: .general)
            return granted
        } catch {
            Logger.error("Notification permission error", error: error, category: .general)
            return false
        }
    }
    
    func checkPermission() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }
    
    // MARK: - Schedule Task Notifications
    
    func scheduleTaskNotifications(for task: TaskDTO) {
        guard let dueDate = task.dueDate, !task.isCompleted else {
            return
        }
        
        // Cancel existing notifications for this task
        cancelTaskNotifications(for: task.id)
        
        let now = Date()
        
        // Due soon - 1 hour before (check preference)
        if dueSoonEnabled {
            let dueSoonDate = dueDate.addingTimeInterval(-3600)
            if dueSoonDate > now {
                scheduleNotification(
                    id: "task-\(task.id)-due-soon",
                    title: "Task Due Soon",
                    body: "📋 \(task.title) is due in 1 hour",
                    date: dueSoonDate
                )
            }
        }
        
        // Due now - at due time (also controlled by dueSoon preference)
        if dueSoonEnabled {
            if dueDate > now {
                scheduleNotification(
                    id: "task-\(task.id)-due-now",
                    title: "Task Due Now",
                    body: "⏰ \(task.title) is due now",
                    date: dueDate
                )
            }
        }
        
        // Overdue - 1 hour after (check preference)
        if overdueEnabled {
            let overdueDate = dueDate.addingTimeInterval(3600)
            if overdueDate > now {
                scheduleNotification(
                    id: "task-\(task.id)-overdue",
                    title: "Task Overdue!",
                    body: "🚨 \(task.title) is overdue!",
                    date: overdueDate
                )
            }
        }
        
        Logger.debug("Scheduled notifications for task: \(task.title)", category: .general)
    }
    
    func cancelTaskNotifications(for taskId: Int) {
        let ids = [
            "task-\(taskId)-due-soon",
            "task-\(taskId)-due-now",
            "task-\(taskId)-overdue",
            "escalation-\(taskId)-start",
            "escalation-\(taskId)-warning"
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
    
    // MARK: - Escalation Notifications
    
    func scheduleEscalationNotification(id: String, title: String, body: String, date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        
        let timeInterval = max(date.timeIntervalSinceNow, 1)
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: timeInterval,
            repeats: false
        )
        
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.error("Failed to schedule escalation notification: \(id)", error: error, category: .general)
            }
        }
    }
    
    // MARK: - Morning Briefing
    
    func scheduleMorningBriefing(taskCount: Int) {
        // Cancel existing
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["morning-briefing"])
        
        // Check preference
        guard morningBriefingEnabled else { return }
        guard taskCount > 0 else { return }
        
        // Schedule for 8am tomorrow
        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let content = UNMutableNotificationContent()
        content.title = "Good Morning!"
        content.body = "☀️ You have \(taskCount) task\(taskCount == 1 ? "" : "s") due today"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "morning-briefing", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.error("Failed to schedule morning briefing", error: error, category: .general)
            }
        }
    }
    
    // MARK: - Helper
    
    private func scheduleNotification(id: String, title: String, body: String, date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: date.timeIntervalSinceNow,
            repeats: false
        )
        
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.error("Failed to schedule notification: \(id)", error: error, category: .general)
            }
        }
    }
    
    // MARK: - Clear All
    
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}
