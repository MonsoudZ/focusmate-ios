import Combine
import Foundation
import UserNotifications

#if DEBUG

/// Test helper for simulating and debugging push notifications
/// Only available in DEBUG builds
@MainActor
final class NotificationTestHelper: ObservableObject {
    static let shared = NotificationTestHelper()

    @Published var scheduledNotifications: [ScheduledNotification] = []
    @Published var lastSimulatedRoute: String?

    private init() {}

    // MARK: - Scheduled Notification Info

    struct ScheduledNotification: Identifiable {
        let id: String
        let title: String
        let body: String
        let triggerDate: Date?
        let triggerType: String

        var timeUntilFire: String {
            guard let date = triggerDate else { return "Unknown" }
            let interval = date.timeIntervalSinceNow
            if interval <= 0 { return "Past" }
            if interval < 60 { return "\(Int(interval))s" }
            if interval < 3600 { return "\(Int(interval / 60))m" }
            return "\(Int(interval / 3600))h \(Int((interval.truncatingRemainder(dividingBy: 3600)) / 60))m"
        }
    }

    // MARK: - Fetch Scheduled Notifications

    func refreshScheduledNotifications() async {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()

        scheduledNotifications = requests.map { request in
            let triggerDate: Date?
            let triggerType: String

            if let timeTrigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                triggerDate = timeTrigger.nextTriggerDate()
                triggerType = "Time Interval"
            } else if let calendarTrigger = request.trigger as? UNCalendarNotificationTrigger {
                triggerDate = calendarTrigger.nextTriggerDate()
                triggerType = "Calendar"
            } else {
                triggerDate = nil
                triggerType = "Unknown"
            }

            return ScheduledNotification(
                id: request.identifier,
                title: request.content.title,
                body: request.content.body,
                triggerDate: triggerDate,
                triggerType: triggerType
            )
        }.sorted { ($0.triggerDate ?? .distantFuture) < ($1.triggerDate ?? .distantFuture) }
    }

    // MARK: - Quick Test Notifications (fire in seconds)

    /// Schedule a "Due Soon" notification that fires in specified seconds
    func scheduleDueSoonTest(taskId: Int = 999, taskTitle: String = "Test Task", delaySeconds: TimeInterval = 5) {
        scheduleTestNotification(
            id: "task-\(taskId)-due-soon",
            title: "Task Due Soon",
            body: "📋 \(taskTitle) is due in 1 hour",
            delay: delaySeconds
        )
    }

    /// Schedule a "Due Now" notification that fires in specified seconds
    func scheduleDueNowTest(taskId: Int = 999, taskTitle: String = "Test Task", delaySeconds: TimeInterval = 5) {
        scheduleTestNotification(
            id: "task-\(taskId)-due-now",
            title: "Task Due Now",
            body: "⏰ \(taskTitle) is due now",
            delay: delaySeconds
        )
    }

    /// Schedule an "Overdue" notification that fires in specified seconds
    func scheduleOverdueTest(taskId: Int = 999, taskTitle: String = "Test Task", delaySeconds: TimeInterval = 5) {
        scheduleTestNotification(
            id: "task-\(taskId)-overdue",
            title: "Task Overdue!",
            body: "🚨 \(taskTitle) is overdue!",
            delay: delaySeconds
        )
    }

    /// Schedule an escalation start notification
    func scheduleEscalationStartTest(taskId: Int = 999, taskTitle: String = "Test Task", delaySeconds: TimeInterval = 5) {
        scheduleTestNotification(
            id: "escalation-\(taskId)-start",
            title: "Task Overdue",
            body: "⏰ \"\(taskTitle)\" is overdue. Complete it within 2 hours to avoid app blocking.",
            delay: delaySeconds,
            timeSensitive: true
        )
    }

    /// Schedule an escalation warning notification
    func scheduleEscalationWarningTest(taskId: Int = 999, taskTitle: String = "Test Task", delaySeconds: TimeInterval = 5) {
        scheduleTestNotification(
            id: "escalation-\(taskId)-warning",
            title: "30 Minutes Left",
            body: "⚠️ Apps will be blocked in 30 minutes. Complete \"\(taskTitle)\" now!",
            delay: delaySeconds,
            timeSensitive: true
        )
    }

    /// Schedule a morning briefing notification
    func scheduleMorningBriefingTest(taskCount: Int = 3, delaySeconds: TimeInterval = 5) {
        scheduleTestNotification(
            id: "morning-briefing",
            title: "Good Morning!",
            body: "☀️ You have \(taskCount) task\(taskCount == 1 ? "" : "s") due today",
            delay: delaySeconds
        )
    }

    /// Schedule a simulated nudge notification (mimics remote push)
    func scheduleNudgeTest(taskId: Int = 999, delaySeconds: TimeInterval = 5) {
        let content = UNMutableNotificationContent()
        content.title = "Nudge"
        content.body = "Someone nudged your task!"
        content.sound = .default
        content.userInfo = [
            "type": "nudge",
            "task_id": taskId
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delaySeconds, repeats: false)
        let request = UNNotificationRequest(identifier: "test-nudge-\(taskId)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.error("Failed to schedule test nudge", error: error, category: .general)
            } else {
                Logger.debug("Test nudge scheduled for \(delaySeconds)s", category: .general)
            }
        }
    }

    // MARK: - Simulate Deep Link Routing

    /// Simulate tapping a task notification (tests deep link routing)
    func simulateTaskNotificationTap(taskId: Int) {
        let route = DeepLinkRoute(localNotificationIdentifier: "task-\(taskId)-due-now")
        if let route = route {
            lastSimulatedRoute = "Task \(taskId)"
            AppRouter.shared.handleDeepLink(route)
            Logger.debug("Simulated task notification tap for task \(taskId)", category: .general)
        }
    }

    /// Simulate tapping a morning briefing notification
    func simulateMorningBriefingTap() {
        let route = DeepLinkRoute(localNotificationIdentifier: "morning-briefing")
        if let route = route {
            lastSimulatedRoute = "Today"
            AppRouter.shared.handleDeepLink(route)
            Logger.debug("Simulated morning briefing tap", category: .general)
        }
    }

    /// Simulate receiving a nudge push notification
    func simulateNudgePush(taskId: Int) {
        let userInfo: [AnyHashable: Any] = [
            "type": "nudge",
            "task_id": taskId
        ]
        let route = DeepLinkRoute(pushNotificationUserInfo: userInfo)
        if let route = route {
            lastSimulatedRoute = "Nudge → Task \(taskId)"
            AppRouter.shared.handleDeepLink(route)
            Logger.debug("Simulated nudge push for task \(taskId)", category: .general)
        }
    }

    // MARK: - Utility

    /// Clear all pending and delivered notifications
    func clearAllNotifications() {
        NotificationService.shared.clearAllNotifications()
        Task {
            await refreshScheduledNotifications()
        }
        Logger.debug("Cleared all notifications", category: .general)
    }

    /// Cancel a specific notification
    func cancelNotification(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        Task {
            await refreshScheduledNotifications()
        }
    }

    /// Check current notification permission status
    func checkPermissionStatus() async -> String {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return "Not Determined"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }

    // MARK: - Private

    private func scheduleTestNotification(
        id: String,
        title: String,
        body: String,
        delay: TimeInterval,
        timeSensitive: Bool = false
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if timeSensitive {
            content.interruptionLevel = .timeSensitive
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delay, 1), repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.error("Failed to schedule test notification: \(id)", error: error, category: .general)
            } else {
                Logger.debug("Test notification '\(id)' scheduled for \(delay)s", category: .general)
            }
        }

        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await refreshScheduledNotifications()
        }
    }
}

#endif
