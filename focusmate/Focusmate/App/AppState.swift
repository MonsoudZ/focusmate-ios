import Combine
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var auth = AuthStore()
    @Published var isLoading = false
    @Published var error: FocusmateError?

    // Services
    private(set) lazy var listService = ListService(apiClient: auth.api)
    private(set) lazy var taskService = TaskService(apiClient: auth.api)
    private(set) lazy var deviceService = DeviceService(apiClient: auth.api)

    init() {
        SentryService.shared.initialize()
        
        Task {
            await setupServices()
        }
    }

    private func setupServices() async {
        guard auth.jwt != nil else { return }
        
        // Defer device registration to improve app launch time
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await registerDevice()
        }
    }

    private func registerDevice() async {
        do {
            _ = try await deviceService.registerDevice()
            Logger.info("Device registered successfully", category: .api)
        } catch {
            Logger.warning("Device registration skipped: \(error)", category: .api)
        }
    }

    func clearError() {
        error = nil
    }
}
