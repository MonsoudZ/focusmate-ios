import Foundation

/// Shared UserDefaults for cross-process state between the main app
/// and extensions (IntentiaMonitor, IntentiaShield).
///
/// Uses an App Group container so all processes read/write to the same
/// memory-mapped plist file on disk. This is the single source of truth
/// for escalation state — no dual-write to `UserDefaults.standard`.
enum SharedDefaults {
  static let suiteName = "group.com.monsoudzanaty.focusmate"

  static var store: UserDefaults {
    UserDefaults(suiteName: suiteName) ?? .standard
  }

  // MARK: - Keys

  /// Encoded `Set<ApplicationToken>` — which apps to block.
  static let selectedAppsKey = "Shared_SelectedApps"

  /// Encoded `Set<ActivityCategoryToken>` — which categories to block.
  static let selectedCategoriesKey = "Shared_SelectedCategories"

  /// `[Int]` — IDs of overdue tasks (empty = no blocking warranted).
  static let overdueTaskIdsKey = "Shared_OverdueTaskIds"

  /// `Date` — when the grace period started.
  static let gracePeriodStartTimeKey = "Shared_GracePeriodStartTime"
}
