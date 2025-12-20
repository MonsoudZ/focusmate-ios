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
  private(set) lazy var locationMonitoringService = LocationMonitoringService.shared
  private(set) lazy var calendarIntegrationService = CalendarIntegrationService.shared
  private(set) lazy var remindersIntegrationService = RemindersIntegrationService.shared
  private(set) lazy var siriShortcutsService = SiriShortcutsService.shared
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

    // Setup location-based task monitoring
    self.setupLocationMonitoring()

    // Setup Siri Shortcuts handling
    self.setupSiriShortcutsHandling()
  }

  private func setupServices() async {
    // Performance: Defer non-critical operations to improve app launch time
    if self.auth.jwt != nil {
      // Defer device registration and location setup by 1 second
      // This allows the UI to become interactive first
      Task {
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        await self.registerDeviceWithErrorHandling()
        await self.registerLocationBasedTasks()
      }
    }
  }

  private func registerDeviceWithErrorHandling() async {
    do {
      // Request push permissions first
      let hasPermission = await notificationService.requestPermissions()

      if hasPermission, let pushToken = notificationService.pushToken {
        Logger.debug("Registering device with valid APNS token", category: .notification)
        let response = try await deviceService.registerDevice(pushToken: pushToken)
        Logger.info("Device registered successfully with ID: \(response.device.id)", category: .notification)
      } else {
        Logger.debug("Registering device without push token (permissions not granted or token not available)", category: .notification)
        Logger.debug("This is normal for simulator or when push notifications are not available", category: .notification)
        let response = try await deviceService.registerDevice()
        Logger.info("Device registered successfully with ID: \(response.device.id)", category: .notification)
      }
    } catch let apiError as APIError {
      // Device registration is optional - suppress errors in development
      switch apiError {
      case .badStatus(422, _, _):
        Logger.warning("Device registration skipped - validation failed (expected in development)", category: .notification)
      case .badStatus(401, _, _):
        Logger.warning("Device registration skipped - unauthorized", category: .notification)
      case .badStatus(500, _, _):
        Logger.warning("Device registration skipped - server error", category: .notification)
      default:
        Logger.warning("Device registration skipped: \(apiError)", category: .notification)
      }
    } catch {
      Logger.warning("Device registration skipped: \(error)", category: .notification)
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
      Logger.debug("WebSocket connection initiated", category: .websocket)
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
      Logger.warning("Invalid task update data", category: .websocket)
      return
    }

    Logger.debug("Processing task update: \(taskData)", category: .websocket)

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

      Logger.info("Task update processed and broadcasted", category: .websocket)
    } catch {
      Logger.error("Failed to parse task update", error: error, category: .websocket)
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

    Logger.debug("Push token received, updating device registration", category: .notification)
    self.notificationService.setPushToken(token)

    // Update device registration with push token
    Task {
      do {
        try await self.deviceService.updateDeviceToken(token)
        Logger.info("Device push token updated successfully", category: .notification)
      } catch {
        Logger.error("Failed to update device push token", error: error, category: .notification)
      }
    }
  }

  private func handleNotificationTap(_ notification: Notification) async {
    guard let taskId = notification.userInfo?["task_id"] as? Int,
          let listId = notification.userInfo?["list_id"] as? Int
    else {
      Logger.error("Invalid notification data", category: .notification)
      return
    }

    Logger.debug("Opening task \(taskId) in list \(listId)", category: .notification)

    // Set the current list and selected item
    // This will trigger navigation to the task
    Task {
      // Performance: Use AppState's shared services instead of creating new instances
      do {
        let lists = try await self.listService.fetchLists()
        if let list = lists.first(where: { $0.id == listId }) {
          self.currentList = list

          let items = try await self.itemService.fetchItems(listId: listId)
          if let task = items.first(where: { $0.id == taskId }) {
            self.selectedItem = task
            Logger.info("Task opened successfully", category: .notification)
          }
        }
      } catch {
        Logger.error("Failed to open task from notification", error: error, category: .notification)
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
    Logger.warning("WebSocket connection failed, switching to HTTP polling mode", category: .websocket)
    Logger.debug("App will continue to work with HTTP requests for data synchronization", category: .websocket)

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
            Logger.debug("HTTP polling triggered data sync request", category: .sync)

            do {
              try await self.syncCoordinator.syncAll()
              Logger.info("Data sync completed via HTTP polling", category: .sync)
            } catch {
              Logger.error("Data sync failed via HTTP polling", error: error, category: .sync)
              // Report sync errors to Sentry
              sentryService.captureError(error, context: ["source": "http_polling"])
            }
          }

  // MARK: - Location-Based Task Management

  private func setupLocationMonitoring() {
    // Listen for location trigger activations
    NotificationCenter.default.addObserver(
      forName: .taskLocationTriggerActivated,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      Task { @MainActor in
        await self?.handleLocationTrigger(notification)
      }
    }
  }

  private func handleLocationTrigger(_ notification: Notification) async {
    guard let taskId = notification.userInfo?["taskId"] as? Int,
          let triggerType = notification.userInfo?["triggerType"] as? String
    else {
      Logger.warning("Invalid location trigger data", category: .location)
      return
    }

    Logger.info("Location trigger activated for task \(taskId): \(triggerType)", category: .location)

    // The LocationMonitoringService already sends notifications
    // Here we can add any additional app-level logic if needed
    // For example, refreshing task lists or updating UI state
  }

  private func registerLocationBasedTasks() async {
    Logger.debug("Registering location-based tasks for geofencing", category: .location)

    // Performance: Fetch all lists and their tasks concurrently
    do {
      let lists = try await listService.fetchLists()

      // Fetch items for all lists concurrently
      try await withThrowingTaskGroup(of: [Item].self) { group in
        for list in lists {
          group.addTask {
            try await self.itemService.fetchItems(listId: list.id)
          }
        }

        for try await items in group {
          let locationBasedTasks = items.filter { $0.location_based }

          if !locationBasedTasks.isEmpty {
            Logger.debug("Found \(locationBasedTasks.count) location-based tasks", category: .location)
            locationMonitoringService.registerGeofences(for: locationBasedTasks)
          }
        }
      }

      Logger.info("Location-based task registration complete", category: .location)
    } catch {
      Logger.error("Failed to register location-based tasks", error: error, category: .location)
      // Don't fail app launch if geofence registration fails
      sentryService.captureError(error, context: ["source": "location_geofence_registration"])
    }
  }

  // MARK: - Siri Shortcuts Integration

  private func setupSiriShortcutsHandling() {
    // Listen for Siri action requests
    NotificationCenter.default.addObserver(
      forName: .handleSiriAction,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      Task { @MainActor in
        await self?.handleSiriAction(notification)
      }
    }
  }

  private func handleSiriAction(_ notification: Notification) async {
    guard let action = notification.userInfo?["action"] as? SiriAction else {
      Logger.error("Invalid Siri action", category: .ui)
      return
    }

    Logger.info("Handling Siri action: \(action)", category: .ui)

    switch action {
    case .createTask(let title, let listName):
      await handleCreateTaskFromSiri(title: title, listName: listName)

    case .completeTask(let title):
      await handleCompleteTaskFromSiri(title: title)

    case .viewTasks(let listName):
      await handleViewTasksFromSiri(listName: listName)
    }
  }

  private func handleCreateTaskFromSiri(title: String?, listName: String?) async {
    Logger.info("Creating task from Siri - \(title ?? "New Task") in \(listName ?? "Default")", category: .ui)
    // Post notification for UI to handle
    NotificationCenter.default.post(
      name: .showCreateTask,
      object: nil,
      userInfo: [
        "title": title as Any,
        "listName": listName as Any
      ]
    )
  }

  private func handleCompleteTaskFromSiri(title: String?) async {
    guard let title = title else {
      Logger.warning("No title provided for complete task action", category: .ui)
      return
    }

    Logger.info("Completing task from Siri - \(title)", category: .ui)

    // Performance: Search for task by title across all lists concurrently
    do {
      let lists = try await listService.fetchLists()

      // Fetch items from all lists concurrently
      try await withThrowingTaskGroup(of: Item?.self) { group in
        for list in lists {
          group.addTask {
            let items = try await self.itemService.fetchItems(listId: list.id)
            // Find uncompleted task matching title
            for item in items {
              if item.title == title {
                let completed = await MainActor.run { item.isCompleted }
                if !completed {
                  return item
                }
              }
            }
            return nil
          }
        }

        // Find first matching task
        for try await task in group {
          if let task = task {
            // Complete the task
            _ = try await itemService.completeItem(id: task.id, completed: true, completionNotes: "Completed via Siri")
            Logger.info("Task '\(title)' completed via Siri", category: .ui)
            group.cancelAll() // Stop searching once found
            return
          }
        }
      }

      Logger.warning("Task '\(title)' not found", category: .ui)
    } catch {
      Logger.error("Failed to complete task via Siri", error: error, category: .ui)
    }
  }

  private func handleViewTasksFromSiri(listName: String?) async {
    Logger.info("Viewing tasks from Siri - \(listName ?? "All")", category: .ui)
    // Post notification for UI to handle
    NotificationCenter.default.post(
      name: .showTaskList,
      object: nil,
      userInfo: ["listName": listName as Any]
    )
  }

  // MARK: - Sentry Integration

  private func setupAuthListener() {
    // Monitor auth state changes to update Sentry user context
    // This could be implemented with Combine or by observing the auth property
    // For now, we'll set user context when auth is available
    Task { @MainActor in
      // Check if user is already authenticated
      if auth.jwt != nil {
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

      Logger.info("Updated Sentry user context for user ID: \(profile.id)", category: .general)
    } catch {
      Logger.warning("Could not fetch user profile for Sentry context: \(error)", category: .general)
    }
  }

  /// Call this when user logs out
  func clearSentryContext() {
    sentryService.clearUser()
    Logger.info("Cleared Sentry user context", category: .general)
  }
}

// MARK: - Additional Notification Names

extension Notification.Name {
  static let mergeTaskUpdate = Notification.Name("mergeTaskUpdate")
  static let pushTokenReceived = Notification.Name("pushTokenReceived")
  static let showCreateTask = Notification.Name("showCreateTask")
  static let showTaskList = Notification.Name("showTaskList")
  static let showDegradedStorageWarning = Notification.Name("showDegradedStorageWarning")
}
