import Foundation

#if !targetEnvironment(simulator)
  import DeviceActivity
#endif

@Observable
@MainActor
final class EscalationService {
  static let shared = EscalationService()

  var isInGracePeriod: Bool = false
  var gracePeriodEndTime: Date?
  var overdueTaskIds: Set<Int> = []

  /// Set when Screen Time authorization is revoked during an active escalation.
  /// Intentionally NOT cleared by `resetAll()` — it needs to survive so the UI
  /// can show a recovery banner explaining what happened and linking to Settings.
  /// Cleared by: user tapping the banner, or authorization being re-granted on foreground.
  var authorizationWasRevoked: Bool = false

  @ObservationIgnored private var gracePeriodTimer: Timer?
  @ObservationIgnored private var checkTimer: Timer?

  private var gracePeriodMinutes: Int {
    AppConfiguration.Escalation.gracePeriodMinutes
  }

  private var warningMinutes: Int {
    AppConfiguration.Escalation.warningMinutes
  }

  @ObservationIgnored private let gracePeriodStartKey = SharedDefaults.gracePeriodStartTimeKey
  @ObservationIgnored private let overdueTaskIdsKey = SharedDefaults.overdueTaskIdsKey

  // Legacy keys for one-time migration from UserDefaults.standard
  @ObservationIgnored private let legacyGracePeriodStartKey = "Escalation_GracePeriodStart"
  @ObservationIgnored private let legacyOverdueTaskIdsKey = "Escalation_OverdueTaskIds"

  @ObservationIgnored private let screenTimeService: ScreenTimeManaging
  @ObservationIgnored private let notificationService: NotificationService

  init(
    screenTimeService: (any ScreenTimeManaging)? = nil,
    notificationService: NotificationService? = nil
  ) {
    self.screenTimeService = screenTimeService ?? ScreenTimeService.shared
    self.notificationService = notificationService ?? .shared
    self.migrateFromStandardDefaultsIfNeeded()
    self.loadState()

    // Only start periodic check if there's persisted escalation state
    if !self.overdueTaskIds.isEmpty || SharedDefaults.store.object(forKey: self.gracePeriodStartKey) != nil {
      self.checkGracePeriodStatus()
      self.startPeriodicCheck()
    }
  }

  // MARK: - Task Became Overdue

  func taskBecameOverdue(_ task: TaskDTO) {
    guard !self.overdueTaskIds.contains(task.id) else {
      Logger.debug("Escalation: Task \(task.id) already tracked, skipping", category: .general)
      return
    }

    self.overdueTaskIds.insert(task.id)
    self.saveState()

    self.startPeriodicCheck()

    // Start grace period if not already running and blocking is possible
    let authorized = self.screenTimeService.isAuthorized
    let hasApps = self.screenTimeService.hasSelections
    let alreadyBlocking = self.screenTimeService.isBlocking

    Logger.info(
      "Escalation: Task \(task.id) became overdue. "
        + "authorized=\(authorized), hasSelections=\(hasApps), "
        + "isBlocking=\(alreadyBlocking), isInGracePeriod=\(self.isInGracePeriod)",
      category: .general
    )

    if !self.isInGracePeriod, !alreadyBlocking, authorized, hasApps {
      self.startGracePeriod()
    } else if !authorized {
      Logger.warning("Escalation: Cannot start grace period — Screen Time not authorized", category: .general)
    } else if !hasApps {
      Logger.warning("Escalation: Cannot start grace period — no apps selected for blocking", category: .general)
    }

    // Schedule notifications
    self.scheduleGracePeriodNotifications(for: task)
  }

  // MARK: - Task Completed

  func taskCompleted(_ taskId: Int) {
    self.overdueTaskIds.remove(taskId)
    self.saveState()

    // Cancel notifications for this task
    self.notificationService.cancelTaskNotifications(for: taskId)

    // If no more overdue tasks, stop blocking
    if self.overdueTaskIds.isEmpty {
      self.stopEscalation()
    }

    Logger.info("Task \(taskId) completed. Remaining overdue: \(self.overdueTaskIds.count)", category: .general)
  }

  // MARK: - Grace Period

  private func startGracePeriod() {
    let now = Date()
    let endTime = now.addingTimeInterval(TimeInterval(self.gracePeriodMinutes * 60))
    self.gracePeriodEndTime = endTime
    self.isInGracePeriod = true

    SharedDefaults.store.set(now, forKey: self.gracePeriodStartKey)
    self.saveState()

    self.scheduleGracePeriodTimer(interval: TimeInterval(self.gracePeriodMinutes * 60))

    // Schedule out-of-process monitor as failsafe.
    // If the user kills the app, the OS still fires intervalDidEnd
    // in the IntentiaMonitor extension to activate blocking.
    self.scheduleDeviceActivityMonitor(endTime: endTime)

    Logger.info("Grace period started. Ends at \(endTime)", category: .general)
  }

  /// Schedules a timer for the grace period.
  ///
  /// Design: Since EscalationService is @MainActor, the timer callback runs on main thread.
  /// We use weak self to avoid retain cycles, then guard before calling the method.
  private func scheduleGracePeriodTimer(interval: TimeInterval) {
    self.gracePeriodTimer?.invalidate()
    self.gracePeriodTimer = Timer.scheduledTimer(
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
      "Escalation: Grace period ended. Overdue tasks: \(self.overdueTaskIds.count), "
        + "authorized=\(self.screenTimeService.isAuthorized), hasSelections=\(self.screenTimeService.hasSelections)",
      category: .general
    )

    self.isInGracePeriod = false
    self.gracePeriodEndTime = nil
    self.gracePeriodTimer?.invalidate()
    self.gracePeriodTimer = nil

    // Start blocking if there are still overdue tasks
    if !self.overdueTaskIds.isEmpty {
      self.startBlocking()
    } else {
      Logger.info("Escalation: No overdue tasks remaining, skipping blocking", category: .general)
    }
  }

  private func startBlocking() {
    Logger.info(
      "Escalation: startBlocking called. authorized=\(self.screenTimeService.isAuthorized), "
        + "hasSelections=\(self.screenTimeService.hasSelections), overdueCount=\(self.overdueTaskIds.count)",
      category: .general
    )

    guard self.screenTimeService.isAuthorized else {
      Logger.warning("Escalation: Cannot block — Screen Time authorization revoked", category: .general)
      self.authorizationWasRevoked = true
      self.sendAuthorizationRevokedNotification()
      self.resetAll()
      return
    }

    guard self.screenTimeService.hasSelections else {
      Logger.warning("Escalation: Cannot block — no apps selected for blocking", category: .general)
      self.sendBlockingSkippedNotification()
      self.resetAll()
      return
    }

    self.screenTimeService.startBlocking()
    self.sendBlockingStartedNotification()

    Logger.info("Escalation: App blocking ACTIVATED", category: .general)
  }

  private func stopEscalation() {
    self.resetAll()
    Logger.info("Escalation stopped - all tasks cleared", category: .general)
  }

  /// Fully resets escalation state. Called on sign-out to ensure app blocking
  /// is removed before auth state is cleared.
  func resetAll() {
    // Stop grace period timer
    self.gracePeriodTimer?.invalidate()
    self.gracePeriodTimer = nil
    self.isInGracePeriod = false
    self.gracePeriodEndTime = nil

    // Stop periodic check timer (no need to check when not in escalation)
    self.checkTimer?.invalidate()
    self.checkTimer = nil

    // Cancel the out-of-process failsafe. If the extension's intervalDidEnd
    // is already queued, it will check overdueTaskIds (now empty) and skip.
    #if !targetEnvironment(simulator)
      DeviceActivityCenter().stopMonitoring([.gracePeriod])
    #endif

    // Stop blocking
    self.screenTimeService.stopBlocking()

    // Clear overdue tracking
    self.overdueTaskIds.removeAll()

    // Clear persisted state
    SharedDefaults.store.removeObject(forKey: self.gracePeriodStartKey)
    self.saveState()
  }

  // MARK: - Notifications

  private func scheduleGracePeriodNotifications(for task: TaskDTO) {
    let now = Date()

    // The immediate "overdue" notification is handled by
    // NotificationService (task-{id}-overdue, 1 hour after due).
    // Only schedule the 30-minute-before-blocking warning here
    // to avoid duplicate overdue alerts.

    // 30-minute warning before app blocking
    let warningTime = now.addingTimeInterval(TimeInterval((self.gracePeriodMinutes - self.warningMinutes) * 60))
    self.notificationService.scheduleEscalationNotification(
      id: "escalation-\(task.id)-warning",
      title: "30 Minutes Left",
      body: "⚠️ Apps will be blocked in 30 minutes. Complete \"\(task.title)\" now!",
      date: warningTime
    )
  }

  private func sendBlockingStartedNotification() {
    self.notificationService.scheduleEscalationNotification(
      id: "escalation-blocking-started",
      title: "Apps Blocked",
      body: "🚫 Distracting apps are now blocked. Complete your overdue tasks in Intentia to unlock.",
      date: Date().addingTimeInterval(1)
    )
  }

  private func sendBlockingSkippedNotification() {
    self.notificationService.scheduleEscalationNotification(
      id: "escalation-blocking-skipped",
      title: "No Apps to Block",
      body: "You have overdue tasks but haven't selected any apps to block. Set this up in Settings.",
      date: Date().addingTimeInterval(1)
    )
  }

  private func sendAuthorizationRevokedNotification() {
    self.notificationService.scheduleEscalationNotification(
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
    if self.authorizationWasRevoked, self.screenTimeService.isAuthorized {
      self.authorizationWasRevoked = false
      return
    }

    guard !self.overdueTaskIds.isEmpty else { return }
    guard !self.screenTimeService.isAuthorized else { return }

    // Authorization was revoked while we had active escalation state.
    // The OS silently ignores ManagedSettings writes without authorization,
    // so any "blocking" we think is active is actually a no-op. Reset everything.
    Logger.warning("Screen Time authorization revoked during active escalation — resetting", category: .general)
    self.authorizationWasRevoked = true
    self.sendAuthorizationRevokedNotification()
    self.resetAll()
  }

  /// Clears the revocation flag. Called when the user taps the recovery banner.
  func clearAuthorizationRevocationFlag() {
    self.authorizationWasRevoked = false
  }

  // MARK: - Periodic Check

  /// Starts periodic status checks for grace period restoration after app relaunch.
  ///
  /// Design: Timer callbacks run on main thread since service is @MainActor.
  /// No Task wrapper needed - direct method call is safe.
  private func startPeriodicCheck() {
    guard self.checkTimer == nil else { return }
    self.checkTimer = Timer.scheduledTimer(
      withTimeInterval: AppConfiguration.Escalation.statusCheckIntervalSeconds,
      repeats: true
    ) { [weak self] _ in
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
      let endTime = startTime.addingTimeInterval(TimeInterval(self.gracePeriodMinutes * 60))

      if Date() >= endTime {
        // Grace period should have ended
        if !self.overdueTaskIds.isEmpty, !self.screenTimeService.isBlocking {
          self.gracePeriodEnded()
        }
      } else if !self.isInGracePeriod {
        // Restore grace period
        self.gracePeriodEndTime = endTime
        self.isInGracePeriod = true

        let remaining = endTime.timeIntervalSinceNow
        self.scheduleGracePeriodTimer(interval: remaining)
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
        Logger.info(
          "Escalation: Grace period too short for DeviceActivity (\(Int(interval))s), skipping",
          category: .general
        )
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
    SharedDefaults.store.set(ids, forKey: self.overdueTaskIdsKey)
  }

  private func loadState() {
    if let ids = SharedDefaults.store.array(forKey: overdueTaskIdsKey) as? [Int] {
      self.overdueTaskIds = Set(ids)
    }
  }

  /// One-time migration from `UserDefaults.standard` to the App Group container.
  /// Existing users may have escalation state stored in standard defaults.
  private func migrateFromStandardDefaultsIfNeeded() {
    let shared = SharedDefaults.store
    let standard = UserDefaults.standard

    // Skip if shared defaults already have escalation data
    if shared.object(forKey: self.overdueTaskIdsKey) != nil { return }

    let hasLegacyIds = standard.array(forKey: self.legacyOverdueTaskIdsKey) != nil
    let hasLegacyStart = standard.object(forKey: self.legacyGracePeriodStartKey) != nil

    guard hasLegacyIds || hasLegacyStart else { return }

    if let ids = standard.array(forKey: legacyOverdueTaskIdsKey) {
      shared.set(ids, forKey: self.overdueTaskIdsKey)
    }
    if let startTime = standard.object(forKey: legacyGracePeriodStartKey) {
      shared.set(startTime, forKey: self.gracePeriodStartKey)
    }

    standard.removeObject(forKey: self.legacyOverdueTaskIdsKey)
    standard.removeObject(forKey: self.legacyGracePeriodStartKey)

    Logger.info("EscalationService: Migrated state from standard to shared defaults", category: .general)
  }

  // MARK: - Task Tracking

  /// Check if a task is being tracked for escalation (was overdue and hasn't been completed)
  func isTaskTracked(_ taskId: Int) -> Bool {
    self.overdueTaskIds.contains(taskId)
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
