import Foundation

final class AppSettings {
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
