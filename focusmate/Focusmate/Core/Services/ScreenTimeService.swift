import Foundation
import Combine

#if !targetEnvironment(simulator)
import FamilyControls
import ManagedSettings
import DeviceActivity

@MainActor
final class ScreenTimeService: ObservableObject, ScreenTimeManaging {
  static let shared = ScreenTimeService()

  private let store = ManagedSettingsStore()
  private let center = AuthorizationCenter.shared

  @Published var authorizationStatus: AuthorizationStatus = .notDetermined
  @Published var selectedApps: Set<ApplicationToken> = []
  @Published var selectedCategories: Set<ActivityCategoryToken> = []
  @Published var isBlocking: Bool = false

  private let appsKey = "ScreenTime_SelectedApps"
  private let categoriesKey = "ScreenTime_SelectedCategories"

  private init() {
    loadSelections()
    updateAuthorizationStatus()
  }

  // MARK: - Authorization

  func requestAuthorization() async throws {
    try await center.requestAuthorization(for: .individual)
    updateAuthorizationStatus()
  }

  func updateAuthorizationStatus() {
    authorizationStatus = center.authorizationStatus
  }

  var isAuthorized: Bool {
    authorizationStatus == .approved
  }

  // MARK: - App Selection

  func updateSelections(apps: Set<ApplicationToken>, categories: Set<ActivityCategoryToken>) {
    selectedApps = apps
    selectedCategories = categories
    saveSelections()
  }

  // MARK: - Blocking

  func startBlocking() {
    guard isAuthorized else {
      Logger.warning("Cannot block - not authorized", category: .general)
      return
    }

    guard !selectedApps.isEmpty || !selectedCategories.isEmpty else {
      Logger.warning("Cannot block - no apps selected", category: .general)
      return
    }

    store.shield.applications = selectedApps
    store.shield.applicationCategories = .specific(selectedCategories)

    isBlocking = true
    Logger.info("App blocking started", category: .general)
  }

  func stopBlocking() {
    store.shield.applications = nil
    store.shield.applicationCategories = nil

    isBlocking = false
    Logger.info("App blocking stopped", category: .general)
  }

  // MARK: - Persistence

  private func saveSelections() {
    let appsData: Data
    let categoriesData: Data

    do {
      appsData = try JSONEncoder().encode(selectedApps)
      categoriesData = try JSONEncoder().encode(selectedCategories)
    } catch {
      Logger.error("Failed to encode selections, not saving: \(error)", category: .general)
      return
    }

    UserDefaults.standard.set(appsData, forKey: appsKey)
    UserDefaults.standard.set(categoriesData, forKey: categoriesKey)
  }

  private func loadSelections() {
    if let appsData = UserDefaults.standard.data(forKey: appsKey) {
      do {
        selectedApps = try JSONDecoder().decode(Set<ApplicationToken>.self, from: appsData)
      } catch {
        Logger.error("Failed to decode selected apps: \(error)", category: .general)
      }
    }
    if let categoriesData = UserDefaults.standard.data(forKey: categoriesKey) {
      do {
        selectedCategories = try JSONDecoder().decode(Set<ActivityCategoryToken>.self, from: categoriesData)
      } catch {
        Logger.error("Failed to decode selected categories: \(error)", category: .general)
      }
    }
  }

  var hasSelections: Bool {
    !selectedApps.isEmpty || !selectedCategories.isEmpty
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

  var isAuthorized: Bool { false }
  var hasSelections: Bool { false }

  func requestAuthorization() async throws {
    Logger.info("ScreenTimeService: FamilyControls unavailable on Simulator", category: .general)
  }

  func updateAuthorizationStatus() {}
  func startBlocking() {}
  func stopBlocking() {}
}

#endif
