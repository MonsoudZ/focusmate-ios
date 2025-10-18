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
    
    // WebSocket for real-time updates
    @Published var webSocketManager = WebSocketManager()
    
    init() {
        // Initialize services when auth is ready
        Task {
            await setupServices()
        }
        
        // Setup WebSocket connection when authenticated
        setupWebSocketConnection()
        
        // Listen for task updates
        setupTaskUpdateListener()
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
    
    // MARK: - WebSocket Management
    
    private func setupWebSocketConnection() {
        // Connect when user is authenticated
        if let jwt = auth.jwt {
            webSocketManager.connect(with: jwt)
            print("🔌 AppState: WebSocket connection initiated")
        }
    }
    
    private func setupTaskUpdateListener() {
        // Listen for task update notifications
        NotificationCenter.default.addObserver(
            forName: .taskUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleTaskUpdate(notification)
        }
    }
    
    private func handleTaskUpdate(_ notification: Notification) {
        guard let taskData = notification.userInfo?["task"] as? [String: Any] else {
            print("🔌 AppState: Invalid task update data")
            return
        }
        
        print("🔌 AppState: Processing task update: \(taskData)")
        
        // Parse the updated task and merge it
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: taskData)
            let updatedTask = try JSONDecoder().decode(Item.self, from: jsonData)
            
            // Notify all ItemViewModels to merge this update
            NotificationCenter.default.post(
                name: .mergeTaskUpdate,
                object: nil,
                userInfo: ["updatedTask": updatedTask]
            )
            
            print("✅ AppState: Task update processed and broadcasted")
        } catch {
            print("❌ AppState: Failed to parse task update: \(error)")
        }
    }
}

// MARK: - Additional Notification Names

extension Notification.Name {
    static let mergeTaskUpdate = Notification.Name("mergeTaskUpdate")
}


