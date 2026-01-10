import Combine
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var auth = AuthStore()
    @Published var isLoading = false
    @Published var error: FocusmateError?

    private var cancellables = Set<AnyCancellable>()

    // Services
    private(set) lazy var listService = ListService(apiClient: auth.api)
    private(set) lazy var taskService = TaskService(apiClient: auth.api)
    private(set) lazy var deviceService = DeviceService(apiClient: auth.api)
    private(set) lazy var tagService = TagService(apiClient: auth.api)

    init() {
        SentryService.shared.initialize()
        
        // Forward auth changes to trigger AppState updates
        auth.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        Task {
            await setupServices()
        }
    }

    private func setupServices() async {
        guard auth.jwt != nil else { return }
        
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
