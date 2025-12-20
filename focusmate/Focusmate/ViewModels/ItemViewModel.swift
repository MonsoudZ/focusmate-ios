import Combine
import CoreLocation
import Foundation
import SwiftData

@MainActor
final class ItemViewModel: ObservableObject {
  @Published var items: [Item] = []
  @Published var isLoading = false
  @Published var error: FocusmateError?
  @Published var selectedItem: Item?
  @Published var isOnline = false
  @Published var lastSyncTime: Date?

  // Batch operation state
  @Published var isSelectionMode = false
  @Published var selectedTaskIds: Set<Int> = []
  @Published var batchOperationInProgress = false
  @Published var batchOperationResult: BatchOperationResult?

  private let itemService: ItemService
  private let swiftDataManager: SwiftDataManager
  private let syncCoordinator: SyncCoordinator?
  private let apiClient: APIClient
  private var batchOperationService: BatchOperationService
  private var cancellables = Set<AnyCancellable>()

  init(
    itemService: ItemService,
    swiftDataManager: SwiftDataManager,
    syncCoordinator: SyncCoordinator? = nil,
    apiClient: APIClient
  ) {
    self.itemService = itemService
    self.swiftDataManager = swiftDataManager
    self.syncCoordinator = syncCoordinator
    self.apiClient = apiClient
    self.batchOperationService = BatchOperationService(apiClient: apiClient)
    self.setupTaskUpdateListener()
    self.updateSyncStatus()
  }

  private func updateSyncStatus() {
    self.isOnline = self.swiftDataManager.syncStatus.isOnline
    self.lastSyncTime = self.swiftDataManager.syncStatus.lastSuccessfulSync
  }

  func performFullSync() async {
    self.isLoading = true
    self.error = nil

    do {
      if let syncCoordinator = syncCoordinator {
        try await syncCoordinator.syncAll()
        self.lastSyncTime = syncCoordinator.lastSyncTime
      } else {
        Logger.warning("No SyncCoordinator available, skipping full sync", category: .sync)
      }
      self.updateSyncStatus()
      Logger.info("Full sync completed", category: .sync)
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      Logger.error("Full sync failed", error: error, category: .sync)
    }

    self.isLoading = false
  }

  func loadItems(listId: Int) async {
    self.isLoading = true
    self.error = nil

    do {
      // Performance: Skip user validation - JWT validation in API client is sufficient
      // This eliminates an extra API call on every data load

      // First, try to load from local SwiftData storage
      self.items = self.itemService.fetchItemsFromLocal(listId: listId)
      Logger.info("Loaded \(self.items.count) items from local storage for list \(listId)", category: .database)

      // Then attempt to sync with server
      try await self.itemService.syncItemsForList(listId: listId)

      // Reload from local storage after sync
      self.items = self.itemService.fetchItemsFromLocal(listId: listId)
      Logger.info("Synced and reloaded \(self.items.count) items for list \(listId)", category: .sync)

    } catch {
      // Handle specific error types
      if let apiError = error as? APIError {
        switch apiError {
        case .badStatus(404, _, _):
          Logger.warning("List not found (404), refreshing lists data", category: .sync)
          // Trigger a full data refresh to handle stale data
          await self.refreshListsData()
          self.error = ErrorHandler.shared.handle(error)
        case .badStatus(500, _, _):
          Logger.warning("Server error (500), clearing cache and refreshing", category: .sync)
          await self.clearAllCachedData()
          await self.refreshListsData()
          self.error = .custom("SERVER_ERROR", "Server error occurred. Data has been refreshed.")
        case .unauthorized:
          Logger.warning("Unauthorized access, clearing cache and requiring re-authentication", category: .auth)
          await self.clearAllCachedData()
          self.error = .custom("AUTH_ERROR", "Please log in again")
        default:
          Logger.warning("Sync failed, showing local data: \(error)", category: .sync)
          if self.items.isEmpty {
            self.error = ErrorHandler.shared.handle(error)
          }
        }
      } else {
        Logger.warning("Sync failed, showing local data: \(error)", category: .sync)
        if self.items.isEmpty {
          self.error = ErrorHandler.shared.handle(error)
        }
      }
    }

    self.isLoading = false
  }

  private func refreshListsData() async {
    Logger.debug("Refreshing lists data due to 404 error", category: .sync)
    do {
      // Clear all cached data first
      await self.clearAllCachedData()

      // Perform full sync if SyncCoordinator is available
      if let syncCoordinator = syncCoordinator {
        try await syncCoordinator.syncAll()
        Logger.info("Lists data refreshed successfully", category: .sync)
      } else {
        Logger.warning("No SyncCoordinator available for refresh", category: .sync)
      }
    } catch {
      Logger.error("Failed to refresh lists data", error: error, category: .sync)
    }
  }

  private func clearAllCachedData() async {
    Logger.debug("Clearing all cached data due to data inconsistency", category: .database)
    // Clear local SwiftData cache
    self.swiftDataManager.deleteAllData()
    // Clear items array
    self.items = []
    Logger.info("All cached data cleared", category: .database)
  }

  // Performance: Removed validateUserIdentity() function
  // JWT validation in API client is sufficient for auth checks
  // This eliminates an extra API call on every data load (50% reduction in network requests)

  func createItem(
    listId: Int,
    name: String,
    description: String?,
    dueDate: Date?,
    isVisible: Bool = true,
    isRecurring: Bool = false,
    recurrencePattern: String? = nil,
    recurrenceInterval: Int? = nil,
    recurrenceDays: [Int]? = nil,
    recurrenceTime: String? = nil,
    locationBased: Bool = false,
    locationName: String? = nil,
    locationLatitude: Double? = nil,
    locationLongitude: Double? = nil,
    locationRadiusMeters: Int? = nil,
    notifyOnArrival: Bool = false,
    notifyOnDeparture: Bool = false
  ) async {
    self.isLoading = true
    self.error = nil

    // Enhanced client-side validation
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else {
      self.error = .custom("VALIDATION_ERROR", "Task title is required")
      self.isLoading = false
      return
    }

    guard trimmedName.count <= 255 else {
      self.error = .custom("VALIDATION_ERROR", "Task title must be 255 characters or less")
      self.isLoading = false
      return
    }

    do {
      let newItem = try await itemService.createItem(
        listId: listId,
        name: trimmedName,
        description: description,
        dueDate: dueDate,
        isVisible: isVisible,
        isRecurring: isRecurring,
        recurrencePattern: recurrencePattern,
        recurrenceInterval: recurrenceInterval,
        recurrenceDays: recurrenceDays,
        recurrenceTime: recurrenceTime,
        locationBased: locationBased,
        locationName: locationName,
        locationLatitude: locationLatitude,
        locationLongitude: locationLongitude,
        locationRadiusMeters: locationRadiusMeters,
        notifyOnArrival: notifyOnArrival,
        notifyOnDeparture: notifyOnDeparture
      )
      self.items.append(newItem)
      Logger.info("Created item: \(newItem.title)", category: .database)

      // Register geofence if this is a location-based task
      if locationBased, locationLatitude != nil, locationLongitude != nil {
        registerGeofenceForTask(newItem)
      }
    } catch let apiError as APIError {
      // Handle specific API errors
      switch apiError {
      case let .badStatus(422, message, _):
        self.error = .custom("VALIDATION_ERROR", message ?? "Invalid task data")
      case .badStatus(404, _, _):
        self.error = .custom("NOT_FOUND", "List not found. Please refresh your data.")
      case .unauthorized:
        self.error = .unauthorized("You are not authorized to create tasks in this list")
      default:
        self.error = ErrorHandler.shared.handle(apiError)
      }
      Logger.error("Failed to create item", error: apiError, category: .database)
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      Logger.error("Failed to create item", error: error, category: .database)
    }

    self.isLoading = false
  }

  func clearError() {
    self.error = nil
  }

  func updateItem(
    id: Int,
    name: String?,
    description: String?,
    completed: Bool?,
    dueDate: Date?,
    isVisible: Bool? = nil,
    isRecurring: Bool? = nil,
    recurrencePattern: String? = nil,
    recurrenceInterval: Int? = nil,
    recurrenceDays: [Int]? = nil,
    locationBased: Bool? = nil,
    locationName: String? = nil,
    locationLatitude: Double? = nil,
    locationLongitude: Double? = nil,
    locationRadiusMeters: Int? = nil,
    notifyOnArrival: Bool? = nil,
    notifyOnDeparture: Bool? = nil
  ) async {
    self.isLoading = true
    self.error = nil

    do {
      let updatedItem = try await itemService.updateItem(
        id: id,
        name: name,
        description: description,
        completed: completed,
        dueDate: dueDate,
        isVisible: isVisible,
        isRecurring: isRecurring,
        recurrencePattern: recurrencePattern,
        recurrenceInterval: recurrenceInterval,
        recurrenceDays: recurrenceDays,
        locationBased: locationBased,
        locationName: locationName,
        locationLatitude: locationLatitude,
        locationLongitude: locationLongitude,
        locationRadiusMeters: locationRadiusMeters,
        notifyOnArrival: notifyOnArrival,
        notifyOnDeparture: notifyOnDeparture
      )
      if let index = items.firstIndex(where: { $0.id == id }) {
        self.items[index] = updatedItem
      }
      Logger.info("Updated item: \(updatedItem.title)", category: .database)
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      Logger.error("Failed to update item", error: error, category: .database)
    }

    self.isLoading = false
  }

  func deleteItem(id: Int) async {
    self.isLoading = true
    self.error = nil

    // Optimistically remove from UI
    let originalItems = self.items
    self.items.removeAll { $0.id == id }

    do {
      // Unregister geofence before deleting
      LocationMonitoringService.shared.unregisterGeofence(taskId: id)

      try await self.itemService.deleteItem(id: id)
      Logger.info("Deleted item with id: \(id)", category: .database)
    } catch {
      // If deletion failed, restore the item
      self.items = originalItems
      self.error = ErrorHandler.shared.handle(error, context: "Delete Task")
      Logger.error("Failed to delete item", error: error, category: .database)
    }

    self.isLoading = false
  }

  func completeItem(id: Int, completed: Bool, completionNotes: String?) async {
    self.isLoading = true
    self.error = nil

    do {
      let updatedItem = try await itemService.completeItem(
        id: id,
        completed: completed,
        completionNotes: completionNotes
      )
      if let index = items.firstIndex(where: { $0.id == id }) {
        // Temporary workaround: If Rails API doesn't set completed_at, set it locally
        if completed, updatedItem.completed_at == nil {
          Logger.debug("Rails API didn't set completed_at, setting locally", category: .database)
          var localItem = updatedItem
          // Create a new Item with completed_at set to current time
          let currentTime = Date().ISO8601Format()
          localItem = Item(
            id: localItem.id,
            list_id: localItem.list_id,
            title: localItem.title,
            description: localItem.description,
            due_at: localItem.due_at,
            completed_at: currentTime, // Set completion time
            priority: localItem.priority,
            can_be_snoozed: localItem.can_be_snoozed,
            notification_interval_minutes: localItem.notification_interval_minutes,
            requires_explanation_if_missed: localItem.requires_explanation_if_missed,
            overdue: localItem.overdue,
            minutes_overdue: localItem.minutes_overdue,
            requires_explanation: localItem.requires_explanation,
            is_recurring: localItem.is_recurring,
            recurrence_pattern: localItem.recurrence_pattern,
            recurrence_interval: localItem.recurrence_interval,
            recurrence_days: localItem.recurrence_days,
            location_based: localItem.location_based,
            location_name: localItem.location_name,
            location_latitude: localItem.location_latitude,
            location_longitude: localItem.location_longitude,
            location_radius_meters: localItem.location_radius_meters,
            notify_on_arrival: localItem.notify_on_arrival,
            notify_on_departure: localItem.notify_on_departure,
            missed_reason: localItem.missed_reason,
            missed_reason_submitted_at: localItem.missed_reason_submitted_at,
            missed_reason_reviewed_at: localItem.missed_reason_reviewed_at,
            creator: localItem.creator,
            created_by_coach: localItem.created_by_coach,
            can_edit: localItem.can_edit,
            can_delete: localItem.can_delete,
            can_complete: localItem.can_complete,
            is_visible: localItem.is_visible,
            escalation: localItem.escalation,
            has_subtasks: localItem.has_subtasks,
            subtasks_count: localItem.subtasks_count,
            subtasks_completed_count: localItem.subtasks_completed_count,
            subtask_completion_percentage: localItem.subtask_completion_percentage,
            created_at: localItem.created_at,
            updated_at: localItem.updated_at
          )
          self.items[index] = localItem
        } else {
          self.items[index] = updatedItem
        }
      }
      Logger.info("Completed item: \(updatedItem.title)", category: .database)
      Logger.debug("completed_at: \(updatedItem.completed_at ?? "nil"), isCompleted: \(updatedItem.isCompleted)", category: .database)

      // Handle recurring task: create next occurrence if task was completed
      if completed && updatedItem.is_recurring {
        await handleRecurringTaskCompletion(updatedItem)
      }
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      Logger.error("Failed to complete item", error: error, category: .database)
    }

    self.isLoading = false
  }

  // MARK: - Recurring Task Handling

  private func handleRecurringTaskCompletion(_ completedTask: Item) async {
    guard let pattern = completedTask.recurrence_pattern,
          let dueDate = completedTask.dueDate
    else {
      Logger.warning("Recurring task missing pattern or due date", category: .database)
      return
    }

    // Calculate next occurrence date
    guard let nextDueDate = RecurringTaskService.calculateNextOccurrence(
      from: dueDate,
      pattern: pattern,
      interval: completedTask.recurrence_interval,
      weekdays: completedTask.recurrence_days
    ) else {
      Logger.error("Failed to calculate next occurrence", category: .database)
      return
    }

    Logger.debug("Creating next occurrence for recurring task - Current due: \(dueDate), Next due: \(nextDueDate)", category: .database)

    // Create the next instance of the recurring task
    await createItem(
      listId: completedTask.list_id,
      name: completedTask.title,
      description: completedTask.description,
      dueDate: nextDueDate,
      isVisible: completedTask.is_visible,
      isRecurring: true,
      recurrencePattern: pattern,
      recurrenceInterval: completedTask.recurrence_interval,
      recurrenceDays: completedTask.recurrence_days,
      locationBased: completedTask.location_based,
      locationName: completedTask.location_name,
      locationLatitude: completedTask.location_latitude,
      locationLongitude: completedTask.location_longitude,
      locationRadiusMeters: completedTask.location_radius_meters,
      notifyOnArrival: completedTask.notify_on_arrival,
      notifyOnDeparture: completedTask.notify_on_departure
    )

    if error == nil {
      Logger.info("Next occurrence created successfully", category: .database)
    }
  }

  func reassignItem(id: Int, newOwnerId: Int, reason: String?) async {
    self.isLoading = true
    self.error = nil

    do {
      let updatedItem = try await itemService.reassignItem(
        id: id,
        newOwnerId: newOwnerId,
        reason: reason
      )
      if let index = items.firstIndex(where: { $0.id == id }) {
        self.items[index] = updatedItem
      }
      Logger.info("Reassigned item: \(updatedItem.title)", category: .database)
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      Logger.error("Failed to reassign item", error: error, category: .database)
    }

    self.isLoading = false
  }

  func addExplanation(id: Int, explanation: String) async {
    self.isLoading = true
    self.error = nil

    do {
      let updatedItem = try await itemService.addExplanation(id: id, explanation: explanation)
      if let index = items.firstIndex(where: { $0.id == id }) {
        self.items[index] = updatedItem
      }
      Logger.info("Added explanation to item: \(updatedItem.title)", category: .database)
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      Logger.error("Failed to add explanation", error: error, category: .database)
    }

    self.isLoading = false
  }

  func snoozeItem(id: Int, snoozeUntil: Date) async {
    self.isLoading = true
    self.error = nil

    do {
      let updatedItem = try await itemService.snoozeItem(id: id, snoozeUntil: snoozeUntil)
      if let index = items.firstIndex(where: { $0.id == id }) {
        self.items[index] = updatedItem
      }
      Logger.info("Snoozed item: \(updatedItem.title) until \(snoozeUntil)", category: .database)
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      Logger.error("Failed to snooze item", error: error, category: .database)
    }

    self.isLoading = false
  }

  // MARK: - Real-time Task Updates

  private func setupTaskUpdateListener() {
    NotificationCenter.default.addObserver(
      forName: .mergeTaskUpdate,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let updatedTask = notification.userInfo?["updatedTask"] as? Item else {
        Logger.warning("Invalid task update data", category: .websocket)
        return
      }
      Task { @MainActor [weak self] in
        guard let self = self else { return }
        Logger.debug("Received task update for item \(updatedTask.id)", category: .websocket)

        if let index = self.items.firstIndex(where: { $0.id == updatedTask.id }) {
          self.items[index] = updatedTask
          Logger.info("Updated task \(updatedTask.id) from WebSocket", category: .websocket)
        }
      }
    }
  }

  private func handleTaskUpdate(_ notification: Notification) {
    guard let updatedTask = notification.userInfo?["updatedTask"] as? Item else {
      Logger.warning("Invalid task update data", category: .websocket)
      return
    }

    Logger.debug("Received task update for item \(updatedTask.id)", category: .websocket)

    // Find and merge the updated task
    if let index = items.firstIndex(where: { $0.id == updatedTask.id }) {
      let oldTask = self.items[index]
      self.items[index] = updatedTask

      Logger.info("Merged task update for '\(updatedTask.title)'", category: .websocket)
      Logger.debug("Status changed from \(oldTask.isCompleted) to \(updatedTask.isCompleted)", category: .websocket)

      // Log specific changes
      if oldTask.title != updatedTask.title {
        Logger.debug("Title changed from '\(oldTask.title)' to '\(updatedTask.title)'", category: .websocket)
      }
      if oldTask.completed_at != updatedTask.completed_at {
        Logger.debug("Completion status changed", category: .websocket)
      }
      if oldTask.description != updatedTask.description {
        Logger.debug("Description updated", category: .websocket)
      }
    } else {
      // Task doesn't exist in current list, might be from another list
      Logger.debug("Task \(updatedTask.id) not found in current list", category: .websocket)
    }
  }

  // MARK: - Location-Based Task Support

  private func registerGeofenceForTask(_ task: Item) {
    guard task.location_based,
          let latitude = task.location_latitude,
          let longitude = task.location_longitude else {
      return
    }

    let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    let radius = CLLocationDistance(task.location_radius_meters)

    LocationMonitoringService.shared.registerGeofence(
      taskId: task.id,
      taskTitle: task.title,
      coordinate: coordinate,
      radius: radius,
      notifyOnArrival: task.notify_on_arrival,
      notifyOnDeparture: task.notify_on_departure
    )
  }

  // MARK: - Batch Operations

  /// Enter selection mode for batch operations
  func enterSelectionMode() {
    isSelectionMode = true
    selectedTaskIds.removeAll()
    batchOperationResult = nil
    Logger.info("Entered selection mode", category: .ui)
  }

  /// Exit selection mode
  func exitSelectionMode() {
    isSelectionMode = false
    selectedTaskIds.removeAll()
    batchOperationResult = nil
    Logger.info("Exited selection mode", category: .ui)
  }

  /// Toggle selection for a task
  func toggleTaskSelection(_ taskId: Int) {
    if selectedTaskIds.contains(taskId) {
      selectedTaskIds.remove(taskId)
    } else {
      selectedTaskIds.insert(taskId)
    }
  }

  /// Select all tasks
  func selectAll() {
    selectedTaskIds = Set(items.map { $0.id })
    Logger.info("Selected all \(selectedTaskIds.count) tasks", category: .ui)
  }

  /// Deselect all tasks
  func deselectAll() {
    selectedTaskIds.removeAll()
    Logger.info("Deselected all tasks", category: .ui)
  }

  /// Perform batch complete operation
  func batchComplete(completed: Bool, completionNotes: String? = nil) async {
    guard !selectedTaskIds.isEmpty else {
      Logger.warning("No tasks selected for batch complete", category: .database)
      return
    }

    batchOperationInProgress = true
    batchOperationResult = nil

    do {
      let result = try await batchOperationService.batchComplete(
        taskIds: Array(selectedTaskIds),
        completed: completed,
        completionNotes: completionNotes
      )

      batchOperationResult = result

      // Reload items to reflect changes
      if let listId = items.first?.list_id {
        await loadItems(listId: listId)
      }

      // Exit selection mode if fully successful
      if result.isFullSuccess {
        exitSelectionMode()
      }

      Logger.info("Batch complete finished - \(result.summaryMessage)", category: .database)
    } catch {
      self.error = FocusmateError.network(error)
      Logger.error("Batch complete failed", error: error, category: .database)
    }

    batchOperationInProgress = false
  }

  /// Perform batch delete operation
  func batchDelete() async {
    guard !selectedTaskIds.isEmpty else {
      Logger.warning("No tasks selected for batch delete", category: .database)
      return
    }

    batchOperationInProgress = true
    batchOperationResult = nil

    // Optimistically remove from UI
    let originalItems = self.items
    items.removeAll { selectedTaskIds.contains($0.id) }

    do {
      let result = try await batchOperationService.batchDelete(
        taskIds: Array(selectedTaskIds)
      )

      batchOperationResult = result

      // Exit selection mode if fully successful
      if result.isFullSuccess {
        exitSelectionMode()
      } else if !result.failedIds.isEmpty {
        // If there were failures, restore failed items
        let failedItemIds = Set(result.failedIds)
        let failedItems = originalItems.filter { failedItemIds.contains($0.id) }
        items.append(contentsOf: failedItems)
      }

      Logger.info("Batch delete finished - \(result.summaryMessage)", category: .database)
    } catch {
      // If entire batch operation failed, restore all items
      self.items = originalItems
      self.error = FocusmateError.network(error)
      Logger.error("Batch delete failed", error: error, category: .database)
    }

    batchOperationInProgress = false
  }

  /// Perform batch move operation
  func batchMove(targetListId: Int) async {
    guard !selectedTaskIds.isEmpty else {
      Logger.warning("No tasks selected for batch move", category: .database)
      return
    }

    batchOperationInProgress = true
    batchOperationResult = nil

    do {
      let result = try await batchOperationService.batchMove(
        taskIds: Array(selectedTaskIds),
        targetListId: targetListId
      )

      batchOperationResult = result

      // Remove moved tasks from local state
      items.removeAll { selectedTaskIds.contains($0.id) }

      // Exit selection mode if fully successful
      if result.isFullSuccess {
        exitSelectionMode()
      }

      Logger.info("Batch move finished - \(result.summaryMessage)", category: .database)
    } catch {
      self.error = FocusmateError.network(error)
      Logger.error("Batch move failed", error: error, category: .database)
    }

    batchOperationInProgress = false
  }

  /// Perform batch reassign operation
  func batchReassign(targetUserId: Int) async {
    guard !selectedTaskIds.isEmpty else {
      Logger.warning("No tasks selected for batch reassign", category: .database)
      return
    }

    batchOperationInProgress = true
    batchOperationResult = nil

    do {
      let result = try await batchOperationService.batchReassign(
        taskIds: Array(selectedTaskIds),
        targetUserId: targetUserId
      )

      batchOperationResult = result

      // Reload items to reflect changes
      if let listId = items.first?.list_id {
        await loadItems(listId: listId)
      }

      // Exit selection mode if fully successful
      if result.isFullSuccess {
        exitSelectionMode()
      }

      Logger.info("Batch reassign finished - \(result.summaryMessage)", category: .database)
    } catch {
      self.error = FocusmateError.network(error)
      Logger.error("Batch reassign failed", error: error, category: .database)
    }

    batchOperationInProgress = false
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}
