import Foundation

final class AppSettings: @unchecked Sendable {
  static let shared = AppSettings()

  private let defaults: UserDefaults

  private init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  private enum Key {
    static let apiEnvironmentOverride = "api_environment_override"
    static let didRequestPushPermission = "did_request_push_permission"
    static let didRequestNotificationsPermission = "did_request_notifications_permission"
    static let didRequestCalendarPermission = "did_request_calendar_permission"
    static let didRequestScreenTimePermission = "did_request_screentime_permission"
    static let calendarSyncEnabled = "calendar_sync_enabled"

    static let hideCompletedToday = "hide_completed_today"
    static let hideCompletedInLists = "hide_completed_in_lists"

    // ✅ NEW
    static let didCompleteAuthenticatedBoot = "did_complete_authenticated_boot"
    static let hasCompletedOnboarding = "has_completed_onboarding"
  }

  // MARK: - API Environment Override

  var apiEnvironmentOverrideRawValue: String? {
    get { self.defaults.string(forKey: Key.apiEnvironmentOverride) }
    set {
      if let newValue {
        self.defaults.set(newValue, forKey: Key.apiEnvironmentOverride)
      } else {
        self.defaults.removeObject(forKey: Key.apiEnvironmentOverride)
      }
    }
  }

  // MARK: - Permission Flags

  var didRequestPushPermission: Bool {
    get { self.defaults.bool(forKey: Key.didRequestPushPermission) }
    set { self.defaults.set(newValue, forKey: Key.didRequestPushPermission) }
  }

  var didRequestNotificationsPermission: Bool {
    get { self.defaults.bool(forKey: Key.didRequestNotificationsPermission) }
    set { self.defaults.set(newValue, forKey: Key.didRequestNotificationsPermission) }
  }

  var didRequestCalendarPermission: Bool {
    get { self.defaults.bool(forKey: Key.didRequestCalendarPermission) }
    set { self.defaults.set(newValue, forKey: Key.didRequestCalendarPermission) }
  }

  var didRequestScreenTimePermission: Bool {
    get { self.defaults.bool(forKey: Key.didRequestScreenTimePermission) }
    set { self.defaults.set(newValue, forKey: Key.didRequestScreenTimePermission) }
  }

  /// Whether calendar sync is enabled (user can toggle off even with permission granted)
  var calendarSyncEnabled: Bool {
    get {
      // Default to true if key doesn't exist but permission was granted
      if self.defaults.object(forKey: Key.calendarSyncEnabled) == nil {
        return self.didRequestCalendarPermission
      }
      return self.defaults.bool(forKey: Key.calendarSyncEnabled)
    }
    set { self.defaults.set(newValue, forKey: Key.calendarSyncEnabled) }
  }

  // MARK: - Authenticated Boot

  /// Indicates whether one-time authenticated boot tasks have completed.
  /// This prevents re-running permission prompts and heavy setup after logout/login.
  var didCompleteAuthenticatedBoot: Bool {
    get { self.defaults.bool(forKey: Key.didCompleteAuthenticatedBoot) }
    set { self.defaults.set(newValue, forKey: Key.didCompleteAuthenticatedBoot) }
  }

  // MARK: - Task Display

  var hideCompletedToday: Bool {
    get { self.defaults.bool(forKey: Key.hideCompletedToday) }
    set { self.defaults.set(newValue, forKey: Key.hideCompletedToday) }
  }

  var hideCompletedInLists: Bool {
    get { self.defaults.bool(forKey: Key.hideCompletedInLists) }
    set { self.defaults.set(newValue, forKey: Key.hideCompletedInLists) }
  }

  // MARK: - Onboarding

  /// Whether the user has completed the onboarding flow after first sign-in.
  var hasCompletedOnboarding: Bool {
    get { self.defaults.bool(forKey: Key.hasCompletedOnboarding) }
    set { self.defaults.set(newValue, forKey: Key.hasCompletedOnboarding) }
  }
}
