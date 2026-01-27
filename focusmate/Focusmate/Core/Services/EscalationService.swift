import Foundation
import Combine

@MainActor
final class EscalationService: ObservableObject {
    static let shared = EscalationService()

    @Published var isInGracePeriod: Bool = false
    @Published var gracePeriodEndTime: Date?
    @Published var overdueTaskIds: Set<Int> = []

    private var gracePeriodTimer: Timer?
    private var checkTimer: Timer?

    private let gracePeriodMinutes: Int = 120 // 2 hours default
    private let warningMinutes: Int = 30

    private let gracePeriodStartKey = "Escalation_GracePeriodStart"
    private let overdueTaskIdsKey = "Escalation_OverdueTaskIds"

    private let screenTimeService: ScreenTimeService
    private let notificationService: NotificationService

    init(
        screenTimeService: ScreenTimeService? = nil,
        notificationService: NotificationService? = nil
    ) {
        self.screenTimeService = screenTimeService ?? .shared
        self.notificationService = notificationService ?? .shared
        loadState()
        startPeriodicCheck()
    }

    // MARK: - Task Became Overdue

    func taskBecameOverdue(_ task: TaskDTO) {
        guard !overdueTaskIds.contains(task.id) else { return }

        overdueTaskIds.insert(task.id)
        saveState()

        // Start grace period if not already running and blocking is possible
        if !isInGracePeriod && !screenTimeService.isBlocking
            && screenTimeService.isAuthorized && screenTimeService.hasSelections {
            startGracePeriod()
        }

        // Schedule notifications
        scheduleGracePeriodNotifications(for: task)

        Logger.info("Task \(task.id) became overdue. Grace period active: \(isInGracePeriod)", category: .general)
    }

    // MARK: - Task Completed

    func taskCompleted(_ taskId: Int) {
        overdueTaskIds.remove(taskId)
        saveState()

        // Cancel notifications for this task
        notificationService.cancelTaskNotifications(for: taskId)

        // If no more overdue tasks, stop blocking
        if overdueTaskIds.isEmpty {
            stopEscalation()
        }

        Logger.info("Task \(taskId) completed. Remaining overdue: \(overdueTaskIds.count)", category: .general)
    }

    // MARK: - Grace Period

    private func startGracePeriod() {
        let endTime = Date().addingTimeInterval(TimeInterval(gracePeriodMinutes * 60))
        gracePeriodEndTime = endTime
        isInGracePeriod = true

        UserDefaults.standard.set(Date(), forKey: gracePeriodStartKey)
        saveState()

        // Schedule timer for when grace period ends
        gracePeriodTimer?.invalidate()
        gracePeriodTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(gracePeriodMinutes * 60),
            repeats: false
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.gracePeriodEnded()
            }
        }

        Logger.info("Grace period started. Ends at \(endTime)", category: .general)
    }

    private func gracePeriodEnded() {
        isInGracePeriod = false
        gracePeriodEndTime = nil
        gracePeriodTimer?.invalidate()
        gracePeriodTimer = nil

        // Start blocking if there are still overdue tasks
        if !overdueTaskIds.isEmpty {
            startBlocking()
        }

        Logger.info("Grace period ended. Overdue tasks: \(overdueTaskIds.count)", category: .general)
    }

    private func startBlocking() {
        guard screenTimeService.hasSelections else {
            Logger.warning("Cannot block - no apps selected", category: .general)
            sendBlockingSkippedNotification()
            // No point keeping escalation state active when blocking is impossible.
            resetAll()
            return
        }

        screenTimeService.startBlocking()
        sendBlockingStartedNotification()

        Logger.info("App blocking started", category: .general)
    }

    private func stopEscalation() {
        resetAll()
        Logger.info("Escalation stopped - all tasks cleared", category: .general)
    }

    /// Fully resets escalation state. Called on sign-out to ensure app blocking
    /// is removed before auth state is cleared.
    func resetAll() {
        // Stop grace period timer
        gracePeriodTimer?.invalidate()
        gracePeriodTimer = nil
        isInGracePeriod = false
        gracePeriodEndTime = nil

        // Stop blocking
        screenTimeService.stopBlocking()

        // Clear overdue tracking
        overdueTaskIds.removeAll()

        // Clear persisted state
        UserDefaults.standard.removeObject(forKey: gracePeriodStartKey)
        saveState()
    }

    // MARK: - Notifications

    private func scheduleGracePeriodNotifications(for task: TaskDTO) {
        let now = Date()

        // Immediate notification
        notificationService.scheduleEscalationNotification(
            id: "escalation-\(task.id)-start",
            title: "Task Overdue",
            body: "⏰ \"\(task.title)\" is overdue. Complete it within 2 hours to avoid app blocking.",
            date: now.addingTimeInterval(1)
        )

        // 30-minute warning
        let warningTime = now.addingTimeInterval(TimeInterval((gracePeriodMinutes - warningMinutes) * 60))
        notificationService.scheduleEscalationNotification(
            id: "escalation-\(task.id)-warning",
            title: "30 Minutes Left",
            body: "⚠️ Apps will be blocked in 30 minutes. Complete \"\(task.title)\" now!",
            date: warningTime
        )
    }

    private func sendBlockingStartedNotification() {
        notificationService.scheduleEscalationNotification(
            id: "escalation-blocking-started",
            title: "Apps Blocked",
            body: "🚫 Distracting apps are now blocked. Complete your overdue tasks in Intentia to unlock.",
            date: Date().addingTimeInterval(1)
        )
    }

    private func sendBlockingSkippedNotification() {
        notificationService.scheduleEscalationNotification(
            id: "escalation-blocking-skipped",
            title: "No Apps to Block",
            body: "You have overdue tasks but haven't selected any apps to block. Set this up in Settings.",
            date: Date().addingTimeInterval(1)
        )
    }

    // MARK: - Periodic Check

    private func startPeriodicCheck() {
        checkTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.checkGracePeriodStatus()
            }
        }
    }

    private func checkGracePeriodStatus() {
        // Restore grace period state if app was killed
        if let startTime = UserDefaults.standard.object(forKey: gracePeriodStartKey) as? Date {
            let endTime = startTime.addingTimeInterval(TimeInterval(gracePeriodMinutes * 60))

            if Date() >= endTime {
                // Grace period should have ended
                if !overdueTaskIds.isEmpty && !screenTimeService.isBlocking {
                    gracePeriodEnded()
                }
            } else if !isInGracePeriod {
                // Restore grace period
                gracePeriodEndTime = endTime
                isInGracePeriod = true

                let remaining = endTime.timeIntervalSinceNow
                gracePeriodTimer?.invalidate()
                gracePeriodTimer = Timer.scheduledTimer(
                    withTimeInterval: remaining,
                    repeats: false
                ) { [weak self] _ in
                    guard let self else { return }
                    Task { @MainActor in
                        self.gracePeriodEnded()
                    }
                }
            }
        }
    }

    // MARK: - Persistence

    private func saveState() {
        let ids = Array(overdueTaskIds)
        UserDefaults.standard.set(ids, forKey: overdueTaskIdsKey)
    }

    private func loadState() {
        if let ids = UserDefaults.standard.array(forKey: overdueTaskIdsKey) as? [Int] {
            overdueTaskIds = Set(ids)
        }
    }

    // MARK: - Grace Period Info

    var gracePeriodRemaining: TimeInterval? {
        guard let endTime = gracePeriodEndTime else { return nil }
        let remaining = endTime.timeIntervalSinceNow
        return remaining > 0 ? remaining : nil
    }

    var gracePeriodRemainingFormatted: String? {
        guard let remaining = gracePeriodRemaining else { return nil }
        let minutes = Int(remaining / 60)
        let hours = minutes / 60
        let mins = minutes % 60

        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}
