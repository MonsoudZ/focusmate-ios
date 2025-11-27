import Combine
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

  private let itemService: ItemService
  private let swiftDataManager: SwiftDataManager
  private let syncCoordinator: SyncCoordinator?
  private let apiClient: APIClient
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
        #if DEBUG
        print("⚠️ ItemViewModel: No SyncCoordinator available, skipping full sync")
        #endif
      }
      self.updateSyncStatus()
      #if DEBUG
      print("✅ ItemViewModel: Full sync completed")
      #endif
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      #if DEBUG
      print("❌ ItemViewModel: Full sync failed: \(error)")
      #endif
    }

    self.isLoading = false
  }

  func loadItems(listId: Int) async {
    self.isLoading = true
    self.error = nil

    do {
      // Validate user identity first
      let isValidUser = await validateUserIdentity()
      if !isValidUser {
        #if DEBUG
        print("⚠️ ItemViewModel: User identity validation failed, clearing cache")
        #endif
        await self.clearAllCachedData()
        self.error = .custom("AUTH_ERROR", "Please log in again")
        self.isLoading = false
        return
      }

      // First, try to load from local SwiftData storage
      self.items = self.itemService.fetchItemsFromLocal(listId: listId)
      #if DEBUG
      print("✅ ItemViewModel: Loaded \(self.items.count) items from local storage for list \(listId)")
      #endif

      // Then attempt to sync with server
      try await self.itemService.syncItemsForList(listId: listId)

      // Reload from local storage after sync
      self.items = self.itemService.fetchItemsFromLocal(listId: listId)
      #if DEBUG
      print("✅ ItemViewModel: Synced and reloaded \(self.items.count) items for list \(listId)")
      #endif

    } catch {
      // Handle specific error types
      if let apiError = error as? APIError {
        switch apiError {
        case .badStatus(404, _, _):
          #if DEBUG
          print("⚠️ ItemViewModel: List not found (404), refreshing lists data")
          #endif
          // Trigger a full data refresh to handle stale data
          await self.refreshListsData()
          self.error = ErrorHandler.shared.handle(error)
        case .badStatus(500, _, _):
          #if DEBUG
          print("⚠️ ItemViewModel: Server error (500), clearing cache and refreshing")
          #endif
          await self.clearAllCachedData()
          await self.refreshListsData()
          self.error = .custom("SERVER_ERROR", "Server error occurred. Data has been refreshed.")
        case .unauthorized:
          #if DEBUG
          print("⚠️ ItemViewModel: Unauthorized access, clearing cache and requiring re-authentication")
          #endif
          await self.clearAllCachedData()
          self.error = .custom("AUTH_ERROR", "Please log in again")
        default:
          #if DEBUG
          print("⚠️ ItemViewModel: Sync failed, showing local data: \(error)")
          #endif
          if self.items.isEmpty {
            self.error = ErrorHandler.shared.handle(error)
          }
        }
      } else {
        #if DEBUG
        print("⚠️ ItemViewModel: Sync failed, showing local data: \(error)")
        #endif
        if self.items.isEmpty {
          self.error = ErrorHandler.shared.handle(error)
        }
      }
    }

    self.isLoading = false
  }

  private func refreshListsData() async {
    #if DEBUG
    print("🔄 ItemViewModel: Refreshing lists data due to 404 error")
    #endif
    do {
      // Clear all cached data first
      await self.clearAllCachedData()

      // Perform full sync if SyncCoordinator is available
      if let syncCoordinator = syncCoordinator {
        try await syncCoordinator.syncAll()
        #if DEBUG
        print("✅ ItemViewModel: Lists data refreshed successfully")
        #endif
      } else {
        #if DEBUG
        print("⚠️ ItemViewModel: No SyncCoordinator available for refresh")
        #endif
      }
    } catch {
      #if DEBUG
      print("❌ ItemViewModel: Failed to refresh lists data: \(error)")
      #endif
    }
  }

  private func clearAllCachedData() async {
    #if DEBUG
    print("🧹 ItemViewModel: Clearing all cached data due to data inconsistency")
    #endif
    // Clear local SwiftData cache
    self.swiftDataManager.deleteAllData()
    // Clear items array
    self.items = []
    #if DEBUG
    print("✅ ItemViewModel: All cached data cleared")
    #endif
  }

  private func validateUserIdentity() async -> Bool {
    #if DEBUG
    print("🔍 ItemViewModel: Validating user identity")
    #endif
    do {
      // Try to call the profile endpoint to validate current user
      let profile: UserProfile = try await apiClient.request(
        "GET",
        "profile",
        body: nil as String?,
        queryParameters: [:]
      )
      #if DEBUG
      print("✅ ItemViewModel: User identity validated - User ID: \(profile.id), Email: \(profile.email)")
      #endif
      return true
    } catch {
      // Profile endpoint might not exist - that's OK, assume valid if we have a token
      if case APIError.badStatus(404, _, _) = error {
        #if DEBUG
        print("ℹ️ ItemViewModel: Profile endpoint not available, skipping validation")
        #endif
        return true
      }
      #if DEBUG
      print("❌ ItemViewModel: User identity validation failed: \(error)")
      #endif
      return false
    }
  }

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
        locationBased: locationBased,
        locationName: locationName,
        locationLatitude: locationLatitude,
        locationLongitude: locationLongitude,
        locationRadiusMeters: locationRadiusMeters,
        notifyOnArrival: notifyOnArrival,
        notifyOnDeparture: notifyOnDeparture
      )
      self.items.append(newItem)
      #if DEBUG
      print("✅ ItemViewModel: Created item: \(newItem.title)")
      #endif
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
      #if DEBUG
      print("❌ ItemViewModel: Failed to create item: \(apiError)")
      #endif
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      #if DEBUG
      print("❌ ItemViewModel: Failed to create item: \(error)")
      #endif
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
      #if DEBUG
      print("✅ ItemViewModel: Updated item: \(updatedItem.title)")
      #endif
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      #if DEBUG
      print("❌ ItemViewModel: Failed to update item: \(error)")
      #endif
    }

    self.isLoading = false
  }

  func deleteItem(id: Int) async {
    self.isLoading = true
    self.error = nil

    do {
      try await self.itemService.deleteItem(id: id)
      self.items.removeAll { $0.id == id }
      #if DEBUG
      print("✅ ItemViewModel: Deleted item with id: \(id)")
      #endif
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      #if DEBUG
      print("❌ ItemViewModel: Failed to delete item: \(error)")
      #endif
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
          #if DEBUG
          print("🔧 ItemViewModel: Rails API didn't set completed_at, setting locally")
          #endif
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
      #if DEBUG
      print("✅ ItemViewModel: Completed item: \(updatedItem.title)")
      #endif
      #if DEBUG
      print("🔍 ItemViewModel: completed_at: \(updatedItem.completed_at ?? "nil")")
      #endif
      #if DEBUG
      print("🔍 ItemViewModel: isCompleted: \(updatedItem.isCompleted)")
      #endif
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      #if DEBUG
      print("❌ ItemViewModel: Failed to complete item: \(error)")
      #endif
    }

    self.isLoading = false
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
      #if DEBUG
      print("✅ ItemViewModel: Reassigned item: \(updatedItem.title)")
      #endif
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      #if DEBUG
      print("❌ ItemViewModel: Failed to reassign item: \(error)")
      #endif
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
      #if DEBUG
      print("✅ ItemViewModel: Added explanation to item: \(updatedItem.title)")
      #endif
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      #if DEBUG
      print("❌ ItemViewModel: Failed to add explanation: \(error)")
      #endif
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
      self?.handleTaskUpdate(notification)
    }
  }

  private func handleTaskUpdate(_ notification: Notification) {
    guard let updatedTask = notification.userInfo?["updatedTask"] as? Item else {
      #if DEBUG
      print("🔌 ItemViewModel: Invalid task update data")
      #endif
      return
    }

    #if DEBUG
    print("🔌 ItemViewModel: Received task update for item \(updatedTask.id)")
    #endif

    // Find and merge the updated task
    if let index = items.firstIndex(where: { $0.id == updatedTask.id }) {
      let oldTask = self.items[index]
      self.items[index] = updatedTask

      #if DEBUG
      print("✅ ItemViewModel: Merged task update for '\(updatedTask.title)'")
      #endif
      #if DEBUG
      print("🔍 ItemViewModel: Status changed from \(oldTask.isCompleted) to \(updatedTask.isCompleted)")
      #endif

      // Log specific changes
      if oldTask.title != updatedTask.title {
        #if DEBUG
        print("🔍 ItemViewModel: Title changed from '\(oldTask.title)' to '\(updatedTask.title)'")
        #endif
      }
      if oldTask.completed_at != updatedTask.completed_at {
        #if DEBUG
        print("🔍 ItemViewModel: Completion status changed")
        #endif
      }
      if oldTask.description != updatedTask.description {
        #if DEBUG
        print("🔍 ItemViewModel: Description updated")
        #endif
      }
    } else {
      // Task doesn't exist in current list, might be from another list
      #if DEBUG
      print("🔌 ItemViewModel: Task \(updatedTask.id) not found in current list")
      #endif
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}
