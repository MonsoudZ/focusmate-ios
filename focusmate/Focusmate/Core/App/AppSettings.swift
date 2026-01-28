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

        // ✅ NEW
        static let didCompleteAuthenticatedBoot = "did_complete_authenticated_boot"
        static let hasCompletedOnboarding = "has_completed_onboarding"
    }

    // MARK: - API Environment Override

    var apiEnvironmentOverrideRawValue: String? {
        get { defaults.string(forKey: Key.apiEnvironmentOverride) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Key.apiEnvironmentOverride)
            } else {
                defaults.removeObject(forKey: Key.apiEnvironmentOverride)
            }
        }
    }

    // MARK: - Permission Flags

    var didRequestPushPermission: Bool {
        get { defaults.bool(forKey: Key.didRequestPushPermission) }
        set { defaults.set(newValue, forKey: Key.didRequestPushPermission) }
    }

    var didRequestNotificationsPermission: Bool {
        get { defaults.bool(forKey: Key.didRequestNotificationsPermission) }
        set { defaults.set(newValue, forKey: Key.didRequestNotificationsPermission) }
    }

    var didRequestCalendarPermission: Bool {
        get { defaults.bool(forKey: Key.didRequestCalendarPermission) }
        set { defaults.set(newValue, forKey: Key.didRequestCalendarPermission) }
    }

    var didRequestScreenTimePermission: Bool {
        get { defaults.bool(forKey: Key.didRequestScreenTimePermission) }
        set { defaults.set(newValue, forKey: Key.didRequestScreenTimePermission) }
    }

    /// Whether calendar sync is enabled (user can toggle off even with permission granted)
    var calendarSyncEnabled: Bool {
        get {
            // Default to true if key doesn't exist but permission was granted
            if defaults.object(forKey: Key.calendarSyncEnabled) == nil {
                return didRequestCalendarPermission
            }
            return defaults.bool(forKey: Key.calendarSyncEnabled)
        }
        set { defaults.set(newValue, forKey: Key.calendarSyncEnabled) }
    }

    // MARK: - Authenticated Boot

    /// Indicates whether one-time authenticated boot tasks have completed.
    /// This prevents re-running permission prompts and heavy setup after logout/login.
    var didCompleteAuthenticatedBoot: Bool {
        get { defaults.bool(forKey: Key.didCompleteAuthenticatedBoot) }
        set { defaults.set(newValue, forKey: Key.didCompleteAuthenticatedBoot) }
    }

    // MARK: - Onboarding

    /// Whether the user has completed the onboarding flow after first sign-in.
    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Key.hasCompletedOnboarding) }
    }
}
