import Foundation
import Combine
import FamilyControls
import ManagedSettings
import DeviceActivity

@MainActor
final class ScreenTimeService: ObservableObject {
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
        // Note: ApplicationToken and ActivityCategoryToken are Codable
        if let appsData = try? JSONEncoder().encode(selectedApps) {
            UserDefaults.standard.set(appsData, forKey: appsKey)
        }
        if let categoriesData = try? JSONEncoder().encode(selectedCategories) {
            UserDefaults.standard.set(categoriesData, forKey: categoriesKey)
        }
    }
    
    private func loadSelections() {
        if let appsData = UserDefaults.standard.data(forKey: appsKey),
           let apps = try? JSONDecoder().decode(Set<ApplicationToken>.self, from: appsData) {
            selectedApps = apps
        }
        if let categoriesData = UserDefaults.standard.data(forKey: categoriesKey),
           let categories = try? JSONDecoder().decode(Set<ActivityCategoryToken>.self, from: categoriesData) {
            selectedCategories = categories
        }
    }
    
    // MARK: - Quick Setup (for onboarding)
    
    func selectDefaults() {
        // This just sets categories - Social and Games
        // The actual category tokens need to come from FamilyActivityPicker
    }
    
    var hasSelections: Bool {
        !selectedApps.isEmpty || !selectedCategories.isEmpty
    }
}
