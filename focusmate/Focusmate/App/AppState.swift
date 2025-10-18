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
    
    // SwiftData Services
    private(set) lazy var swiftDataManager = SwiftDataManager.shared
    private(set) lazy var deltaSyncService = DeltaSyncService(apiClient: auth.api, swiftDataManager: swiftDataManager)
    private(set) lazy var itemService = ItemService(apiClient: auth.api, swiftDataManager: swiftDataManager, deltaSyncService: deltaSyncService)
    
    // WebSocket for real-time updates
    @Published var webSocketManager = WebSocketManager()
    
    // Push notifications
    @Published var notificationService = NotificationService()
    
    init() {
        // Initialize services when auth is ready
        Task {
            await setupServices()
        }
        
        // Setup WebSocket connection when authenticated
        setupWebSocketConnection()
        
        // Listen for task updates
        setupTaskUpdateListener()
        
        // Setup push notifications
        setupPushNotifications()
    }
    
    private func setupServices() async {
        // Register device on app launch
        if auth.jwt != nil {
            do {
                // Request push permissions first
                let hasPermission = await notificationService.requestPermissions()
                
                if hasPermission, let pushToken = notificationService.pushToken {
                    _ = try await deviceService.registerDevice(pushToken: pushToken)
                    print("✅ Device registered with push token")
                } else {
                    _ = try await deviceService.registerDevice()
                    print("✅ Device registered without push token")
                }
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
    
    // MARK: - Push Notification Management
    
    private func setupPushNotifications() {
        // Listen for push token updates
        NotificationCenter.default.addObserver(
            forName: .pushTokenReceived,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handlePushTokenReceived(notification)
        }
        
        // Listen for notification taps
        NotificationCenter.default.addObserver(
            forName: .openTaskFromNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleNotificationTap(notification)
        }
    }
    
    private func handlePushTokenReceived(_ notification: Notification) {
        guard let token = notification.userInfo?["token"] as? String else { return }
        
        print("🔔 AppState: Push token received, updating device registration")
        notificationService.setPushToken(token)
        
        // Update device registration with push token
        Task {
            do {
                try await deviceService.updateDeviceToken(token)
                print("✅ AppState: Device push token updated successfully")
            } catch {
                print("❌ AppState: Failed to update device push token: \(error)")
            }
        }
    }
    
    private func handleNotificationTap(_ notification: Notification) {
        guard let taskId = notification.userInfo?["task_id"] as? Int,
              let listId = notification.userInfo?["list_id"] as? Int else {
            print("❌ AppState: Invalid notification data")
            return
        }
        
        print("🔔 AppState: Opening task \(taskId) in list \(listId)")
        
        // Set the current list and selected item
        // This will trigger navigation to the task
        Task {
            // Load the list first
            let listService = ListService(apiClient: auth.api)
            do {
                let lists = try await listService.fetchLists()
                if let list = lists.first(where: { $0.id == listId }) {
                    currentList = list
                    
                    // Load the specific task
                    let itemService = ItemService(apiClient: auth.api)
                    let items = try await itemService.fetchItems(listId: listId)
                    if let task = items.first(where: { $0.id == taskId }) {
                        selectedItem = task
                        print("✅ AppState: Task opened successfully")
                    }
                }
            } catch {
                print("❌ AppState: Failed to open task from notification: \(error)")
            }
        }
    }
}

// MARK: - Additional Notification Names

extension Notification.Name {
    static let mergeTaskUpdate = Notification.Name("mergeTaskUpdate")
    static let pushTokenReceived = Notification.Name("pushTokenReceived")
}


