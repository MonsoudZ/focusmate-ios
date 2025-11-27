import Combine
import Foundation
import SwiftUI

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
  private(set) lazy var locationService = LocationService()
  private(set) lazy var sentryService = SentryService.shared

  // SwiftData Services
  private(set) lazy var swiftDataManager = SwiftDataManager.shared
  private(set) lazy var itemService = ItemService(
    apiClient: auth.api,
    swiftDataManager: swiftDataManager
  )
  private(set) lazy var listService = ListService(apiClient: auth.api)
  private(set) lazy var subtaskService = SubtaskService(
    apiClient: auth.api,
    swiftDataManager: swiftDataManager
  )
  private(set) lazy var syncCoordinator = SyncCoordinator(
    itemService: itemService,
    listService: listService,
    swiftDataManager: swiftDataManager
  )

  // WebSocket for real-time updates
  @Published var webSocketManager = WebSocketManager()

  // Push notifications
  @Published var notificationService = NotificationService()

  init() {
    // Initialize Sentry for error tracking
    sentryService.initialize()

    // Initialize services when auth is ready
    Task {
      await self.setupServices()
    }

    // Setup WebSocket connection when authenticated
    self.setupWebSocketConnection()

    // Listen for task updates
    self.setupTaskUpdateListener()

    // Setup push notifications
    self.setupPushNotifications()

    // Listen for WebSocket connection failures
    self.setupWebSocketFailureListener()

    // Listen for data sync requests from HTTP polling
    self.setupDataSyncListener()

    // Listen for auth changes to update Sentry user context
    self.setupAuthListener()
  }

  private func setupServices() async {
    // Register device on app launch
    if self.auth.jwt != nil {
      await self.registerDeviceWithErrorHandling()
    }
  }

  private func registerDeviceWithErrorHandling() async {
    do {
      // Request push permissions first
      let hasPermission = await notificationService.requestPermissions()

      if hasPermission, let pushToken = notificationService.pushToken {
        #if DEBUG
        print("📱 AppState: Registering device with valid APNS token")
        #endif
        let response = try await deviceService.registerDevice(pushToken: pushToken)
        #if DEBUG
        print("✅ AppState: Device registered successfully with ID: \(response.device.id)")
        #endif
      } else {
        #if DEBUG
        print("📱 AppState: Registering device without push token (permissions not granted or token not available)")
        #endif
        #if DEBUG
        print("📱 AppState: This is normal for simulator or when push notifications are not available")
        #endif
        let response = try await deviceService.registerDevice()
        #if DEBUG
        print("✅ AppState: Device registered successfully with ID: \(response.device.id)")
        #endif
      }
    } catch let apiError as APIError {
      // Device registration is optional - suppress errors in development
      switch apiError {
      case let .badStatus(422, _, _):
        #if DEBUG
        print("ℹ️ AppState: Device registration skipped - validation failed (expected in development)")
        #endif
      case .badStatus(401, _, _):
        #if DEBUG
        print("ℹ️ AppState: Device registration skipped - unauthorized")
        #endif
      case .badStatus(500, _, _):
        #if DEBUG
        print("ℹ️ AppState: Device registration skipped - server error")
        #endif
      default:
        #if DEBUG
        print("ℹ️ AppState: Device registration skipped: \(apiError)")
        #endif
      }
    } catch {
      #if DEBUG
      print("ℹ️ AppState: Device registration skipped: \(error)")
      #endif
    }
  }

  func clearError() {
    self.error = nil
  }

  // MARK: - WebSocket Management

  private func setupWebSocketConnection() {
    // Connect when user is authenticated
    if let jwt = auth.jwt {
      self.webSocketManager.connect(with: jwt)
      #if DEBUG
      print("🔌 AppState: WebSocket connection initiated")
      #endif
    }
  }

  private func setupTaskUpdateListener() {
    // Listen for task update notifications
    NotificationCenter.default.addObserver(
      forName: .taskUpdated,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      Task { @MainActor in
        await self?.handleTaskUpdate(notification)
      }
    }
  }

  private func handleTaskUpdate(_ notification: Notification) async {
    guard let taskData = notification.userInfo?["task"] as? [String: Any] else {
      #if DEBUG
      print("🔌 AppState: Invalid task update data")
      #endif
      return
    }

    #if DEBUG
    print("🔌 AppState: Processing task update: \(taskData)")
    #endif

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

      #if DEBUG
      print("✅ AppState: Task update processed and broadcasted")
      #endif
    } catch {
      #if DEBUG
      print("❌ AppState: Failed to parse task update: \(error)")
      #endif
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
      Task { @MainActor in
        await self?.handlePushTokenReceived(notification)
      }
    }

    // Listen for notification taps
    NotificationCenter.default.addObserver(
      forName: .openTaskFromNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      Task { @MainActor in
        await self?.handleNotificationTap(notification)
      }
    }
  }

  private func handlePushTokenReceived(_ notification: Notification) async {
    guard let token = notification.userInfo?["token"] as? String else { return }

    #if DEBUG
    print("🔔 AppState: Push token received, updating device registration")
    #endif
    self.notificationService.setPushToken(token)

    // Update device registration with push token
    Task {
      do {
        try await self.deviceService.updateDeviceToken(token)
        #if DEBUG
        print("✅ AppState: Device push token updated successfully")
        #endif
      } catch {
        #if DEBUG
        print("❌ AppState: Failed to update device push token: \(error)")
        #endif
      }
    }
  }

  private func handleNotificationTap(_ notification: Notification) async {
    guard let taskId = notification.userInfo?["task_id"] as? Int,
          let listId = notification.userInfo?["list_id"] as? Int
    else {
      #if DEBUG
      print("❌ AppState: Invalid notification data")
      #endif
      return
    }

    #if DEBUG
    print("🔔 AppState: Opening task \(taskId) in list \(listId)")
    #endif

    // Set the current list and selected item
    // This will trigger navigation to the task
    Task {
      // Load the list first
      let listService = ListService(apiClient: auth.api)
      do {
        let lists = try await listService.fetchLists()
        if let list = lists.first(where: { $0.id == listId }) {
          self.currentList = list

          // Load the specific task
          let itemService = ItemService(
            apiClient: auth.api,
            swiftDataManager: SwiftDataManager.shared
          )
          let items = try await itemService.fetchItems(listId: listId)
          if let task = items.first(where: { $0.id == taskId }) {
            self.selectedItem = task
            #if DEBUG
            print("✅ AppState: Task opened successfully")
            #endif
          }
        }
      } catch {
        #if DEBUG
        print("❌ AppState: Failed to open task from notification: \(error)")
        #endif
      }
    }
  }

  private func setupWebSocketFailureListener() {
    NotificationCenter.default.addObserver(
      forName: .webSocketConnectionFailed,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        await self?.handleWebSocketConnectionFailure()
      }
    }
  }

  private func handleWebSocketConnectionFailure() async {
    #if DEBUG
    print("🔄 AppState: WebSocket connection failed, switching to HTTP polling mode")
    #endif
    #if DEBUG
    print("🔄 AppState: App will continue to work with HTTP requests for data synchronization")
    #endif

    // The app will continue to work normally with HTTP requests
    // WebSocket was just for real-time updates, which are now handled via polling
    // No user action required - the app remains fully functional
  }

  private func setupDataSyncListener() {
    NotificationCenter.default.addObserver(
      forName: .performDataSync,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        await self?.handleDataSyncRequest()
      }
    }
  }

          private func handleDataSyncRequest() async {
            #if DEBUG
            print("🔄 AppState: HTTP polling triggered data sync request")
            #endif

            do {
              try await self.syncCoordinator.syncAll()
              #if DEBUG
              print("✅ AppState: Data sync completed via HTTP polling")
              #endif
            } catch {
              #if DEBUG
              print("❌ AppState: Data sync failed via HTTP polling: \(error)")
              #endif
              // Report sync errors to Sentry
              sentryService.captureError(error, context: ["source": "http_polling"])
            }
          }

  // MARK: - Sentry Integration

  private func setupAuthListener() {
    // Monitor auth state changes to update Sentry user context
    // This could be implemented with Combine or by observing the auth property
    // For now, we'll set user context when auth is available
    Task { @MainActor in
      // Check if user is already authenticated
      if let jwt = auth.jwt {
        await updateSentryUserContext()
      }
    }
  }

  private func updateSentryUserContext() async {
    // Try to fetch user profile and set Sentry context
    do {
      let profile: UserProfile = try await auth.api.request(
        "GET",
        "profile",
        body: nil as String?,
        queryParameters: [:]
      )

      sentryService.setUser(id: profile.id, email: profile.email, name: profile.name)
      sentryService.setTag(value: profile.role, key: "user_role")
      sentryService.setTag(value: profile.timezone, key: "user_timezone")

      #if DEBUG
      print("✅ AppState: Updated Sentry user context for user ID: \(profile.id)")
      #endif
    } catch {
      #if DEBUG
      print("⚠️ AppState: Could not fetch user profile for Sentry context: \(error)")
      #endif
    }
  }

  /// Call this when user logs out
  func clearSentryContext() {
    sentryService.clearUser()
    #if DEBUG
    print("✅ AppState: Cleared Sentry user context")
    #endif
  }
}

// MARK: - Additional Notification Names

extension Notification.Name {
  static let mergeTaskUpdate = Notification.Name("mergeTaskUpdate")
  static let pushTokenReceived = Notification.Name("pushTokenReceived")
}
