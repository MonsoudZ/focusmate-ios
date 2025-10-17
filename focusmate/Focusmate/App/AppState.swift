import Foundation
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var auth = AuthStore()
    @Published var currentList: ListDTO?
    @Published var selectedItem: Item?
    @Published var isLoading = false
    @Published var error: FocusmateError?
    
    // Services
    private(set) lazy var authService = AuthService(apiClient: auth.api)
    private(set) lazy var deviceService = DeviceService(apiClient: auth.api)
    private(set) lazy var escalationService = EscalationService(apiClient: auth.api)
    
    init() {
        // Initialize services when auth is ready
        Task {
            await setupServices()
        }
    }
    
    private func setupServices() async {
        // Register device on app launch
        if auth.jwt != nil {
            do {
                _ = try await deviceService.registerDevice()
                print("✅ Device registered successfully")
            } catch {
                print("❌ Failed to register device: \(error)")
            }
        }
    }
    
    func clearError() {
        error = nil
    }
}


