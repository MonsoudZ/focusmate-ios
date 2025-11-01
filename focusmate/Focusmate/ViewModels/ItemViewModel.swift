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
        print("⚠️ ItemViewModel: No SyncCoordinator available, skipping full sync")
      }
      self.updateSyncStatus()
      print("✅ ItemViewModel: Full sync completed")
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      print("❌ ItemViewModel: Full sync failed: \(error)")
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
        print("⚠️ ItemViewModel: User identity validation failed, clearing cache")
        await self.clearAllCachedData()
        self.error = .custom("AUTH_ERROR", "Please log in again")
        self.isLoading = false
        return
      }

      // First, try to load from local SwiftData storage
      self.items = self.itemService.fetchItemsFromLocal(listId: listId)
      print("✅ ItemViewModel: Loaded \(self.items.count) items from local storage for list \(listId)")

      // Then attempt to sync with server
      try await self.itemService.syncItemsForList(listId: listId)

      // Reload from local storage after sync
      self.items = self.itemService.fetchItemsFromLocal(listId: listId)
      print("✅ ItemViewModel: Synced and reloaded \(self.items.count) items for list \(listId)")

    } catch {
      // Handle specific error types
      if let apiError = error as? APIError {
        switch apiError {
        case .badStatus(404, _, _):
          print("⚠️ ItemViewModel: List not found (404), refreshing lists data")
          // Trigger a full data refresh to handle stale data
          await self.refreshListsData()
          self.error = ErrorHandler.shared.handle(error)
        case .badStatus(500, _, _):
          print("⚠️ ItemViewModel: Server error (500), clearing cache and refreshing")
          await self.clearAllCachedData()
          await self.refreshListsData()
          self.error = .custom("SERVER_ERROR", "Server error occurred. Data has been refreshed.")
        case .unauthorized:
          print("⚠️ ItemViewModel: Unauthorized access, clearing cache and requiring re-authentication")
          await self.clearAllCachedData()
          self.error = .custom("AUTH_ERROR", "Please log in again")
        default:
          print("⚠️ ItemViewModel: Sync failed, showing local data: \(error)")
          if self.items.isEmpty {
            self.error = ErrorHandler.shared.handle(error)
          }
        }
      } else {
        print("⚠️ ItemViewModel: Sync failed, showing local data: \(error)")
        if self.items.isEmpty {
          self.error = ErrorHandler.shared.handle(error)
        }
      }
    }

    self.isLoading = false
  }

  private func refreshListsData() async {
    print("🔄 ItemViewModel: Refreshing lists data due to 404 error")
    do {
      // Clear all cached data first
      await self.clearAllCachedData()
      // TODO: Implement sync when DeltaSyncService is re-enabled
      // try await self.deltaSyncService.syncAll()
      print("✅ ItemViewModel: Lists data refreshed successfully (placeholder)")
    } catch {
      print("❌ ItemViewModel: Failed to refresh lists data: \(error)")
    }
  }

  private func clearAllCachedData() async {
    print("🧹 ItemViewModel: Clearing all cached data due to data inconsistency")
    // Clear local SwiftData cache
    self.swiftDataManager.deleteAllData()
    // Clear items array
    self.items = []
    print("✅ ItemViewModel: All cached data cleared")
  }

  private func validateUserIdentity() async -> Bool {
    print("🔍 ItemViewModel: Validating user identity")
    do {
      // Try to call the profile endpoint to validate current user
      let profile: UserProfile = try await apiClient.request(
        "GET",
        "profile",
        body: nil as String?,
        queryParameters: [:]
      )
      print("✅ ItemViewModel: User identity validated - User ID: \(profile.id), Email: \(profile.email)")
      return true
    } catch {
      // Profile endpoint might not exist - that's OK, assume valid if we have a token
      if case APIError.badStatus(404, _, _) = error {
        print("ℹ️ ItemViewModel: Profile endpoint not available, skipping validation")
        return true
      }
      print("❌ ItemViewModel: User identity validation failed: \(error)")
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
    recurrenceDays: [Int]? = nil
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
        recurrenceDays: recurrenceDays
      )
      self.items.append(newItem)
      print("✅ ItemViewModel: Created item: \(newItem.title)")
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
      print("❌ ItemViewModel: Failed to create item: \(apiError)")
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      print("❌ ItemViewModel: Failed to create item: \(error)")
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
    recurrenceDays: [Int]? = nil
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
        recurrenceDays: recurrenceDays
      )
      if let index = items.firstIndex(where: { $0.id == id }) {
        self.items[index] = updatedItem
      }
      print("✅ ItemViewModel: Updated item: \(updatedItem.title)")
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      print("❌ ItemViewModel: Failed to update item: \(error)")
    }

    self.isLoading = false
  }

  func deleteItem(id: Int) async {
    self.isLoading = true
    self.error = nil

    do {
      try await self.itemService.deleteItem(id: id)
      self.items.removeAll { $0.id == id }
      print("✅ ItemViewModel: Deleted item with id: \(id)")
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      print("❌ ItemViewModel: Failed to delete item: \(error)")
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
          print("🔧 ItemViewModel: Rails API didn't set completed_at, setting locally")
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
      print("✅ ItemViewModel: Completed item: \(updatedItem.title)")
      print("🔍 ItemViewModel: completed_at: \(updatedItem.completed_at ?? "nil")")
      print("🔍 ItemViewModel: isCompleted: \(updatedItem.isCompleted)")
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      print("❌ ItemViewModel: Failed to complete item: \(error)")
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
      print("✅ ItemViewModel: Reassigned item: \(updatedItem.title)")
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      print("❌ ItemViewModel: Failed to reassign item: \(error)")
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
      print("✅ ItemViewModel: Added explanation to item: \(updatedItem.title)")
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      print("❌ ItemViewModel: Failed to add explanation: \(error)")
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
      print("🔌 ItemViewModel: Invalid task update data")
      return
    }

    print("🔌 ItemViewModel: Received task update for item \(updatedTask.id)")

    // Find and merge the updated task
    if let index = items.firstIndex(where: { $0.id == updatedTask.id }) {
      let oldTask = self.items[index]
      self.items[index] = updatedTask

      print("✅ ItemViewModel: Merged task update for '\(updatedTask.title)'")
      print("🔍 ItemViewModel: Status changed from \(oldTask.isCompleted) to \(updatedTask.isCompleted)")

      // Log specific changes
      if oldTask.title != updatedTask.title {
        print("🔍 ItemViewModel: Title changed from '\(oldTask.title)' to '\(updatedTask.title)'")
      }
      if oldTask.completed_at != updatedTask.completed_at {
        print("🔍 ItemViewModel: Completion status changed")
      }
      if oldTask.description != updatedTask.description {
        print("🔍 ItemViewModel: Description updated")
      }
    } else {
      // Task doesn't exist in current list, might be from another list
      print("🔌 ItemViewModel: Task \(updatedTask.id) not found in current list")
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}
