import Combine
import Foundation

#if !targetEnvironment(simulator)
  import DeviceActivity
  import FamilyControls
  import ManagedSettings

  @MainActor
  final class ScreenTimeService: ObservableObject, ScreenTimeManaging {
    static let shared = ScreenTimeService()

    private let store = ManagedSettingsStore()
    private let center = AuthorizationCenter.shared

    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var selectedApps: Set<ApplicationToken> = []
    @Published var selectedCategories: Set<ActivityCategoryToken> = []
    @Published var isBlocking: Bool = false

    private let appsKey = SharedDefaults.selectedAppsKey
    private let categoriesKey = SharedDefaults.selectedCategoriesKey

    // Legacy keys for one-time migration from UserDefaults.standard
    private let legacyAppsKey = "ScreenTime_SelectedApps"
    private let legacyCategoriesKey = "ScreenTime_SelectedCategories"

    private init() {
      self.migrateFromStandardDefaultsIfNeeded()
      self.loadSelections()
      self.updateAuthorizationStatus()
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
      try await self.center.requestAuthorization(for: .individual)
      self.updateAuthorizationStatus()
    }

    func updateAuthorizationStatus() {
      self.authorizationStatus = self.center.authorizationStatus
    }

    var isAuthorized: Bool {
      self.authorizationStatus == .approved
    }

    // MARK: - App Selection

    func updateSelections(apps: Set<ApplicationToken>, categories: Set<ActivityCategoryToken>) {
      self.selectedApps = apps
      self.selectedCategories = categories
      self.saveSelections()
    }

    // MARK: - Blocking

    func startBlocking() {
      guard self.isAuthorized else {
        Logger.warning("Cannot block - not authorized", category: .general)
        return
      }

      guard !self.selectedApps.isEmpty || !self.selectedCategories.isEmpty else {
        Logger.warning("Cannot block - no apps selected", category: .general)
        return
      }

      self.store.shield.applications = self.selectedApps
      self.store.shield.applicationCategories = .specific(self.selectedCategories)

      self.isBlocking = true
      Logger.info("App blocking started", category: .general)
    }

    func stopBlocking() {
      self.store.shield.applications = nil
      self.store.shield.applicationCategories = nil

      self.isBlocking = false
      Logger.info("App blocking stopped", category: .general)
    }

    // MARK: - Persistence

    private func saveSelections() {
      let appsData: Data
      let categoriesData: Data

      do {
        appsData = try JSONEncoder().encode(self.selectedApps)
        categoriesData = try JSONEncoder().encode(self.selectedCategories)
      } catch {
        Logger.error("Failed to encode selections, not saving: \(error)", category: .general)
        return
      }

      SharedDefaults.store.set(appsData, forKey: self.appsKey)
      SharedDefaults.store.set(categoriesData, forKey: self.categoriesKey)
    }

    private func loadSelections() {
      if let appsData = SharedDefaults.store.data(forKey: appsKey) {
        do {
          self.selectedApps = try JSONDecoder().decode(Set<ApplicationToken>.self, from: appsData)
        } catch {
          Logger.error("Failed to decode selected apps: \(error)", category: .general)
        }
      }
      if let categoriesData = SharedDefaults.store.data(forKey: categoriesKey) {
        do {
          self.selectedCategories = try JSONDecoder().decode(Set<ActivityCategoryToken>.self, from: categoriesData)
        } catch {
          Logger.error("Failed to decode selected categories: \(error)", category: .general)
        }
      }
    }

    /// One-time migration from `UserDefaults.standard` to the App Group container.
    /// Existing users have their app selections stored in standard defaults;
    /// we need to copy them to the shared suite so the IntentiaMonitor extension
    /// can read them. After migration, the legacy keys are removed.
    private func migrateFromStandardDefaultsIfNeeded() {
      let shared = SharedDefaults.store

      // Skip if shared defaults already have data (migration already done)
      if shared.data(forKey: self.appsKey) != nil { return }

      let standard = UserDefaults.standard
      let hasLegacyApps = standard.data(forKey: self.legacyAppsKey) != nil
      let hasLegacyCategories = standard.data(forKey: self.legacyCategoriesKey) != nil

      guard hasLegacyApps || hasLegacyCategories else { return }

      if let appsData = standard.data(forKey: legacyAppsKey) {
        shared.set(appsData, forKey: self.appsKey)
      }
      if let categoriesData = standard.data(forKey: legacyCategoriesKey) {
        shared.set(categoriesData, forKey: self.categoriesKey)
      }

      // Clean up legacy keys
      standard.removeObject(forKey: self.legacyAppsKey)
      standard.removeObject(forKey: self.legacyCategoriesKey)

      Logger.info("ScreenTimeService: Migrated selections from standard to shared defaults", category: .general)
    }

    var hasSelections: Bool {
      !self.selectedApps.isEmpty || !self.selectedCategories.isEmpty
    }
  }

#else

  // MARK: - Simulator Stub

  /// On Simulator, FamilyControls daemon doesn't exist. Importing the framework
  /// causes dyld to attempt XPC initialization at process launch, corrupting the
  /// heap before any Swift code executes. This stub provides the same interface
  /// with no-op implementations so all code paths compile without the framework link.
  @MainActor
  final class ScreenTimeService: ObservableObject, ScreenTimeManaging {
    static let shared = ScreenTimeService()

    @Published var isBlocking: Bool = false

    private init() {}

    var isAuthorized: Bool {
      false
    }

    var hasSelections: Bool {
      false
    }

    func requestAuthorization() async throws {
      Logger.info("ScreenTimeService: FamilyControls unavailable on Simulator", category: .general)
    }

    func updateAuthorizationStatus() {}
    func startBlocking() {}
    func stopBlocking() {}
  }

#endif
