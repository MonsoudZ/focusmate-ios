import Foundation
import Combine

#if !targetEnvironment(simulator)
import DeviceActivity
#endif

@MainActor
final class EscalationService: ObservableObject {
    static let shared = EscalationService()

    @Published var isInGracePeriod: Bool = false
    @Published var gracePeriodEndTime: Date?
    @Published var overdueTaskIds: Set<Int> = []

    /// Set when Screen Time authorization is revoked during an active escalation.
    /// Intentionally NOT cleared by `resetAll()` — it needs to survive so the UI
    /// can show a recovery banner explaining what happened and linking to Settings.
    /// Cleared by: user tapping the banner, or authorization being re-granted on foreground.
    @Published var authorizationWasRevoked: Bool = false

    private var gracePeriodTimer: Timer?
    private var checkTimer: Timer?

    private var gracePeriodMinutes: Int { AppConfiguration.Escalation.gracePeriodMinutes }
    private var warningMinutes: Int { AppConfiguration.Escalation.warningMinutes }

    private let gracePeriodStartKey = SharedDefaults.gracePeriodStartTimeKey
    private let overdueTaskIdsKey = SharedDefaults.overdueTaskIdsKey

    // Legacy keys for one-time migration from UserDefaults.standard
    private let legacyGracePeriodStartKey = "Escalation_GracePeriodStart"
    private let legacyOverdueTaskIdsKey = "Escalation_OverdueTaskIds"

    private let screenTimeService: ScreenTimeManaging
    private let notificationService: NotificationService

    init(
        screenTimeService: (any ScreenTimeManaging)? = nil,
        notificationService: NotificationService? = nil
    ) {
        self.screenTimeService = screenTimeService ?? ScreenTimeService.shared
        self.notificationService = notificationService ?? .shared
        migrateFromStandardDefaultsIfNeeded()
        loadState()

        // Only start periodic check if there's persisted escalation state
        if !overdueTaskIds.isEmpty || SharedDefaults.store.object(forKey: gracePeriodStartKey) != nil {
            checkGracePeriodStatus()
            startPeriodicCheck()
        }
    }

    // MARK: - Task Became Overdue

    func taskBecameOverdue(_ task: TaskDTO) {
        guard !overdueTaskIds.contains(task.id) else {
            Logger.debug("Escalation: Task \(task.id) already tracked, skipping", category: .general)
            return
        }

        overdueTaskIds.insert(task.id)
        saveState()

        startPeriodicCheck()

        // Start grace period if not already running and blocking is possible
        let authorized = screenTimeService.isAuthorized
        let hasApps = screenTimeService.hasSelections
        let alreadyBlocking = screenTimeService.isBlocking

        Logger.info(
            "Escalation: Task \(task.id) became overdue. "
            + "authorized=\(authorized), hasSelections=\(hasApps), "
            + "isBlocking=\(alreadyBlocking), isInGracePeriod=\(isInGracePeriod)",
            category: .general
        )

        if !isInGracePeriod && !alreadyBlocking && authorized && hasApps {
            startGracePeriod()
        } else if !authorized {
            Logger.warning("Escalation: Cannot start grace period — Screen Time not authorized", category: .general)
        } else if !hasApps {
            Logger.warning("Escalation: Cannot start grace period — no apps selected for blocking", category: .general)
        }

        // Schedule notifications
        scheduleGracePeriodNotifications(for: task)
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
        let now = Date()
        let endTime = now.addingTimeInterval(TimeInterval(gracePeriodMinutes * 60))
        gracePeriodEndTime = endTime
        isInGracePeriod = true

        SharedDefaults.store.set(now, forKey: gracePeriodStartKey)
        saveState()

        scheduleGracePeriodTimer(interval: TimeInterval(gracePeriodMinutes * 60))

        // Schedule out-of-process monitor as failsafe.
        // If the user kills the app, the OS still fires intervalDidEnd
        // in the IntentiaMonitor extension to activate blocking.
        scheduleDeviceActivityMonitor(endTime: endTime)

        Logger.info("Grace period started. Ends at \(endTime)", category: .general)
    }

    /// Schedules a timer for the grace period.
    ///
    /// Design: Since EscalationService is @MainActor, the timer callback runs on main thread.
    /// We use weak self to avoid retain cycles, then guard before calling the method.
    private func scheduleGracePeriodTimer(interval: TimeInterval) {
        gracePeriodTimer?.invalidate()
        gracePeriodTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.gracePeriodTimer != nil else { return }
                self.gracePeriodEnded()
            }
        }
    }

    private func gracePeriodEnded() {
        Logger.info(
            "Escalation: Grace period ended. Overdue tasks: \(overdueTaskIds.count), "
            + "authorized=\(screenTimeService.isAuthorized), hasSelections=\(screenTimeService.hasSelections)",
            category: .general
        )

        isInGracePeriod = false
        gracePeriodEndTime = nil
        gracePeriodTimer?.invalidate()
        gracePeriodTimer = nil

        // Start blocking if there are still overdue tasks
        if !overdueTaskIds.isEmpty {
            startBlocking()
        } else {
            Logger.info("Escalation: No overdue tasks remaining, skipping blocking", category: .general)
        }
    }

    private func startBlocking() {
        Logger.info(
            "Escalation: startBlocking called. authorized=\(screenTimeService.isAuthorized), "
            + "hasSelections=\(screenTimeService.hasSelections), overdueCount=\(overdueTaskIds.count)",
            category: .general
        )

        guard screenTimeService.isAuthorized else {
            Logger.warning("Escalation: Cannot block — Screen Time authorization revoked", category: .general)
            authorizationWasRevoked = true
            sendAuthorizationRevokedNotification()
            resetAll()
            return
        }

        guard screenTimeService.hasSelections else {
            Logger.warning("Escalation: Cannot block — no apps selected for blocking", category: .general)
            sendBlockingSkippedNotification()
            resetAll()
            return
        }

        screenTimeService.startBlocking()
        sendBlockingStartedNotification()

        Logger.info("Escalation: App blocking ACTIVATED", category: .general)
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

        // Stop periodic check timer (no need to check when not in escalation)
        checkTimer?.invalidate()
        checkTimer = nil

        // Cancel the out-of-process failsafe. If the extension's intervalDidEnd
        // is already queued, it will check overdueTaskIds (now empty) and skip.
        #if !targetEnvironment(simulator)
        DeviceActivityCenter().stopMonitoring([.gracePeriod])
        #endif

        // Stop blocking
        screenTimeService.stopBlocking()

        // Clear overdue tracking
        overdueTaskIds.removeAll()

        // Clear persisted state
        SharedDefaults.store.removeObject(forKey: gracePeriodStartKey)
        saveState()
    }

    // MARK: - Notifications

    private func scheduleGracePeriodNotifications(for task: TaskDTO) {
        let now = Date()

        // The immediate "overdue" notification is handled by
        // NotificationService (task-{id}-overdue, 1 hour after due).
        // Only schedule the 30-minute-before-blocking warning here
        // to avoid duplicate overdue alerts.

        // 30-minute warning before app blocking
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

    private func sendAuthorizationRevokedNotification() {
        notificationService.scheduleEscalationNotification(
            id: "escalation-auth-revoked",
            title: "Screen Time Permission Removed",
            body: "App blocking was disabled because Screen Time access was revoked. Re-enable it in Settings.",
            date: Date().addingTimeInterval(1)
        )
    }

    // MARK: - Authorization Revocation Check

    /// Called on foreground transition to detect if Screen Time authorization
    /// was revoked while the app was backgrounded during an active escalation.
    func checkAuthorizationRevocation() {
        // Auto-clear: if authorization was re-granted while the revocation banner is showing,
        // dismiss it — the user fixed the problem from iOS Settings.
        if authorizationWasRevoked && screenTimeService.isAuthorized {
            authorizationWasRevoked = false
            return
        }

        guard !overdueTaskIds.isEmpty else { return }
        guard !screenTimeService.isAuthorized else { return }

        // Authorization was revoked while we had active escalation state.
        // The OS silently ignores ManagedSettings writes without authorization,
        // so any "blocking" we think is active is actually a no-op. Reset everything.
        Logger.warning("Screen Time authorization revoked during active escalation — resetting", category: .general)
        authorizationWasRevoked = true
        sendAuthorizationRevokedNotification()
        resetAll()
    }

    /// Clears the revocation flag. Called when the user taps the recovery banner.
    func clearAuthorizationRevocationFlag() {
        authorizationWasRevoked = false
    }

    // MARK: - Periodic Check

    /// Starts periodic status checks for grace period restoration after app relaunch.
    ///
    /// Design: Timer callbacks run on main thread since service is @MainActor.
    /// No Task wrapper needed - direct method call is safe.
    private func startPeriodicCheck() {
        guard checkTimer == nil else { return }
        checkTimer = Timer.scheduledTimer(withTimeInterval: AppConfiguration.Escalation.statusCheckIntervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.checkGracePeriodStatus()
            }
        }
    }

    private func checkGracePeriodStatus() {
        // Restore grace period state if app was killed.
        // If the extension already activated blocking while the app was dead,
        // this path idempotently re-writes the same tokens to ManagedSettingsStore.
        if let startTime = SharedDefaults.store.object(forKey: gracePeriodStartKey) as? Date {
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
                scheduleGracePeriodTimer(interval: remaining)
            }
        }
    }

    // MARK: - DeviceActivity Scheduling

    /// Schedules an out-of-process monitor that fires `intervalDidEnd` when
    /// the grace period expires, even if the app is killed or backgrounded.
    ///
    /// **System design:** `DeviceActivitySchedule` uses time-of-day
    /// `DateComponents` (hour/minute/second only), not absolute dates.
    /// The OS manages a per-app daemon that fires the callback in the
    /// IntentiaMonitor extension process. This is the intended third leg
    /// of Apple's FamilyControls + ManagedSettings + DeviceActivity triad.
    private func scheduleDeviceActivityMonitor(endTime: Date) {
        #if !targetEnvironment(simulator)
        let calendar = Calendar.current
        let now = Date()

        // DeviceActivity requires a minimum ~15-minute interval.
        // For shorter grace periods (e.g., testing), skip scheduling —
        // the in-app timer still works when the app is foreground.
        let interval = endTime.timeIntervalSince(now)
        guard interval >= 15 * 60 else {
            Logger.info("Escalation: Grace period too short for DeviceActivity (\(Int(interval))s), skipping", category: .general)
            return
        }

        // Time-of-day components only — using year/month/day causes
        // silent callback failures because the schedule engine treats
        // them as recurring daily windows, not absolute timestamps.
        let startComponents = calendar.dateComponents([.hour, .minute, .second], from: now)
        let endComponents = calendar.dateComponents([.hour, .minute, .second], from: endTime)

        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: false
        )

        do {
            try DeviceActivityCenter().startMonitoring(.gracePeriod, during: schedule)
            Logger.info("Escalation: DeviceActivity monitor scheduled until \(endTime)", category: .general)
        } catch {
            // Non-fatal: the in-app timer is the primary path.
            // The extension is a failsafe for the app-killed case.
            Logger.error("Escalation: Failed to schedule DeviceActivity monitor: \(error)", category: .general)
        }
        #endif
    }

    // MARK: - Persistence

    private func saveState() {
        let ids = Array(overdueTaskIds)
        SharedDefaults.store.set(ids, forKey: overdueTaskIdsKey)
    }

    private func loadState() {
        if let ids = SharedDefaults.store.array(forKey: overdueTaskIdsKey) as? [Int] {
            overdueTaskIds = Set(ids)
        }
    }

    /// One-time migration from `UserDefaults.standard` to the App Group container.
    /// Existing users may have escalation state stored in standard defaults.
    private func migrateFromStandardDefaultsIfNeeded() {
        let shared = SharedDefaults.store
        let standard = UserDefaults.standard

        // Skip if shared defaults already have escalation data
        if shared.object(forKey: overdueTaskIdsKey) != nil { return }

        let hasLegacyIds = standard.array(forKey: legacyOverdueTaskIdsKey) != nil
        let hasLegacyStart = standard.object(forKey: legacyGracePeriodStartKey) != nil

        guard hasLegacyIds || hasLegacyStart else { return }

        if let ids = standard.array(forKey: legacyOverdueTaskIdsKey) {
            shared.set(ids, forKey: overdueTaskIdsKey)
        }
        if let startTime = standard.object(forKey: legacyGracePeriodStartKey) {
            shared.set(startTime, forKey: gracePeriodStartKey)
        }

        standard.removeObject(forKey: legacyOverdueTaskIdsKey)
        standard.removeObject(forKey: legacyGracePeriodStartKey)

        Logger.info("EscalationService: Migrated state from standard to shared defaults", category: .general)
    }

    // MARK: - Task Tracking

    /// Check if a task is being tracked for escalation (was overdue and hasn't been completed)
    func isTaskTracked(_ taskId: Int) -> Bool {
        overdueTaskIds.contains(taskId)
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
