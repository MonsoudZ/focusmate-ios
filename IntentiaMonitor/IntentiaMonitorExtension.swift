import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// OS-managed process that fires when the grace period expires,
/// regardless of whether the main app is running.
///
/// This is the failsafe for the escalation system. When the main app
/// schedules a DeviceActivity interval for the grace period, the OS
/// guarantees `intervalDidEnd` fires even if the app is killed.
///
/// The extension reads shared state (written by EscalationService)
/// and writes directly to ManagedSettingsStore to activate blocking.
/// Both the extension and the main app can activate blocking —
/// ManagedSettingsStore writes are idempotent.
class IntentiaMonitorExtension: DeviceActivityMonitor {
  private let store = ManagedSettingsStore()

  override func intervalDidEnd(for activity: DeviceActivityName) {
    guard activity == .gracePeriod else { return }

    let defaults = SharedDefaults.store

    // If the user completed all overdue tasks and the main app called
    // stopMonitoring(), this callback won't fire. But if there's a race
    // (tasks completed at 119:59), this guard catches it.
    let overdueIds = defaults.array(forKey: SharedDefaults.overdueTaskIdsKey) as? [Int] ?? []
    guard !overdueIds.isEmpty else { return }

    // Decode selected apps from shared defaults
    var apps = Set<ApplicationToken>()
    var categories = Set<ActivityCategoryToken>()

    if let appsData = defaults.data(forKey: SharedDefaults.selectedAppsKey) {
      apps = (try? JSONDecoder().decode(Set<ApplicationToken>.self, from: appsData)) ?? []
    }

    if let categoriesData = defaults.data(forKey: SharedDefaults.selectedCategoriesKey) {
      categories = (try? JSONDecoder().decode(Set<ActivityCategoryToken>.self, from: categoriesData)) ?? []
    }

    guard !apps.isEmpty || !categories.isEmpty else { return }

    // Activate blocking — idempotent write to ManagedSettingsStore.
    // If the main app already activated blocking (because it was
    // in the foreground), this is a harmless no-op.
    self.store.shield.applications = apps
    self.store.shield.applicationCategories = .specific(categories)
  }
}
