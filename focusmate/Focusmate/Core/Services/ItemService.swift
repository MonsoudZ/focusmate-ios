import Foundation
import SwiftData

final class ItemService {
  private let apiClient: APIClient
  private let swiftDataManager: SwiftDataManager
  // private let deltaSyncService: DeltaSyncService // Temporarily disabled

  init(apiClient: APIClient, swiftDataManager: SwiftDataManager, deltaSyncService: Any? = nil) { // Temporarily disabled
    self.apiClient = apiClient
    self.swiftDataManager = swiftDataManager
    // self.deltaSyncService = deltaSyncService // Temporarily disabled
  }

  // MARK: - SwiftData Item Management

  func fetchItemsFromLocal(listId: Int) -> [Item] {
    let fetchDescriptor = FetchDescriptor<TaskItem>(
      predicate: #Predicate { $0.listId == listId }
    )

    do {
      let taskItems = try swiftDataManager.context.fetch(fetchDescriptor)
      return taskItems.map { self.convertTaskItemToItem($0) }
    } catch {
      print("❌ ItemService: Failed to fetch items from local storage: \(error)")
      return []
    }
  }

  func fetchAllItemsFromLocal() -> [TaskItem] {
    let fetchDescriptor = FetchDescriptor<TaskItem>()

    do {
      return try self.swiftDataManager.context.fetch(fetchDescriptor)
    } catch {
      print("❌ ItemService: Failed to fetch all items from local storage: \(error)")
      return []
    }
  }

  func syncItemsForList(listId: Int) async throws {
    // Fetch items from server and save to local storage
    print("🔄 ItemService: Syncing items for list \(listId)")
    let items = try await fetchItems(listId: listId)

    // Save items to local SwiftData storage
    for item in items {
      let taskItem = convertItemToTaskItem(item)

      // Check if item already exists and update it, otherwise insert
      let fetchDescriptor = FetchDescriptor<TaskItem>(
        predicate: #Predicate<TaskItem> { $0.id == item.id }
      )

      if let existing = try? swiftDataManager.context.fetch(fetchDescriptor).first {
        // Update existing item
        existing.title = taskItem.title
        existing.itemDescription = taskItem.itemDescription
        existing.dueAt = taskItem.dueAt
        existing.completedAt = taskItem.completedAt
        existing.priority = taskItem.priority
        existing.isVisible = taskItem.isVisible
        existing.updatedAt = taskItem.updatedAt
      } else {
        // Insert new item
        swiftDataManager.context.insert(taskItem)
      }
    }

    try? swiftDataManager.context.save()
    print("✅ ItemService: Synced \(items.count) items for list \(listId)")
  }

  func syncAllItems() async throws {
    // TODO: Implement sync when DeltaSyncService is re-enabled
    // try await self.deltaSyncService.syncItems()
    print("Sync all items requested (placeholder)")
  }

  // MARK: - Item Management

  func fetchItems(listId: Int) async throws -> [Item] {
    // Rails API returns wrapped response: {tasks: [...], tombstones: [], pagination: {...}}
    let response: ItemsResponse = try await apiClient.request("GET", "lists/\(listId)/tasks", body: nil as String?)
    return response.items
  }

  func fetchItem(id: Int) async throws -> Item {
    let item: Item = try await apiClient.request("GET", "tasks/\(id)", body: nil as String?)
    return item
  }

  func createItem(
    listId: Int,
    name: String,
    description: String?,
    dueDate: Date?,
    isVisible: Bool = true
  ) async throws -> Item {
    let request = CreateItemRequest(
      name: name,
      description: description,
      dueDate: dueDate,
      isVisible: isVisible
    )

    // Debug: Log the request payload
    do {
      let jsonData = try JSONEncoder().encode(request)
      if let jsonString = String(data: jsonData, encoding: .utf8) {
        print("🔍 ItemService: Sending request payload: \(jsonString)")
      }
    } catch {
      print("❌ ItemService: Failed to encode request: \(error)")
    }

    let item: Item = try await apiClient.request("POST", "lists/\(listId)/tasks", body: request)
    print("✅ ItemService: Successfully created item: \(item.title)")
    return item
  }

  func updateItem(
    id: Int,
    name: String?,
    description: String?,
    completed: Bool?,
    dueDate: Date?,
    isVisible: Bool? = nil
  ) async throws -> Item {
    let request = UpdateItemRequest(
      name: name,
      description: description,
      completed: completed,
      dueDate: dueDate,
      isVisible: isVisible
    )

    // Debug: Log the request payload
    do {
      let jsonData = try JSONEncoder().encode(request)
      if let jsonString = String(data: jsonData, encoding: .utf8) {
        print("🔍 ItemService: Sending update request for task \(id): \(jsonString)")
      }
    } catch {
      print("❌ ItemService: Failed to encode update request: \(error)")
    }

    let item: Item = try await apiClient.request("PUT", "tasks/\(id)", body: request)

    // Update local SwiftData cache
    let taskItem = convertItemToTaskItem(item)
    let fetchDescriptor = FetchDescriptor<TaskItem>(
      predicate: #Predicate<TaskItem> { $0.id == item.id }
    )

    if let existing = try? swiftDataManager.context.fetch(fetchDescriptor).first {
      // Update existing item in local storage
      existing.title = taskItem.title
      existing.itemDescription = taskItem.itemDescription
      existing.dueAt = taskItem.dueAt
      existing.completedAt = taskItem.completedAt
      existing.priority = taskItem.priority
      existing.isVisible = taskItem.isVisible
      existing.updatedAt = taskItem.updatedAt
      try? swiftDataManager.context.save()
      print("✅ ItemService: Updated item in local storage")
    }

    return item
  }

  func deleteItem(id: Int) async throws {
    // DELETE requests often return empty responses, handle with EmptyResponse
    _ = try await self.apiClient.request("DELETE", "tasks/\(id)", body: nil as String?) as EmptyResponse
  }

  // MARK: - Item Actions

  func completeItem(id: Int, completed: Bool, completionNotes: String?) async throws -> Item {
    let request = CompleteItemRequest(completed: completed, completionNotes: completionNotes)
    print("🔍 ItemService: Completing task \(id) with completed=\(completed)")
    let item: Item = try await apiClient.request("POST", "tasks/\(id)/complete", body: request)
    print("🔍 ItemService: Received completion response - completed_at: \(item.completed_at ?? "nil")")
    return item
  }

  func reassignItem(id: Int, newOwnerId: Int, reason: String?) async throws -> Item {
    let request = ReassignItemRequest(newOwnerId: newOwnerId, reason: reason)
    let item: Item = try await apiClient.request("PATCH", "tasks/\(id)/reassign", body: request)
    return item
  }

  func addExplanation(id: Int, explanation: String) async throws -> Item {
    let request = AddExplanationRequest(explanation: explanation)
    let item: Item = try await apiClient.request("POST", "tasks/\(id)/explanations", body: request)
    return item
  }

  // MARK: - Request/Response Models

  struct UpdateItemRequest: Codable {
    let name: String?
    let description: String?
    let completed: Bool?
    let dueDate: Date?
    let isVisible: Bool?

    enum CodingKeys: String, CodingKey {
      case name = "title" // Map name to title for Rails API
      case description, completed
      case dueDate = "due_at"
      case isVisible = "is_visible"
    }
  }

  struct CompleteItemRequest: Codable {
    let completed: Bool
    let completionNotes: String?
  }

  struct ReassignItemRequest: Codable {
    let newOwnerId: Int
    let reason: String?
  }

  struct AddExplanationRequest: Codable {
    let explanation: String
  }

  struct ItemResponse: Codable {
    let item: Item
  }

  // MARK: - Helper Methods

  private func convertItemToTaskItem(_ item: Item) -> TaskItem {
    let formatter = ISO8601DateFormatter()

    return TaskItem(
      id: item.id,
      listId: item.list_id,
      title: item.title,
      description: item.description,
      dueAt: item.dueDate, // Already a Date? computed property
      completedAt: item.completed_at.flatMap { formatter.date(from: $0) },
      priority: item.priority,
      canBeSnoozed: item.can_be_snoozed,
      notificationIntervalMinutes: item.notification_interval_minutes,
      requiresExplanationIfMissed: item.requires_explanation_if_missed,
      overdue: item.overdue,
      minutesOverdue: item.minutes_overdue,
      requiresExplanation: item.requires_explanation,
      isRecurring: item.is_recurring,
      recurrencePattern: item.recurrence_pattern,
      recurrenceInterval: item.recurrence_interval,
      recurrenceDays: item.recurrence_days,
      locationBased: item.location_based,
      locationName: item.location_name,
      locationLatitude: item.location_latitude,
      locationLongitude: item.location_longitude,
      locationRadiusMeters: item.location_radius_meters,
      notifyOnArrival: item.notify_on_arrival,
      notifyOnDeparture: item.notify_on_departure,
      missedReason: item.missed_reason,
      missedReasonSubmittedAt: item.missed_reason_submitted_at.flatMap { formatter.date(from: $0) },
      missedReasonReviewedAt: item.missed_reason_reviewed_at.flatMap { formatter.date(from: $0) },
      createdByCoach: item.created_by_coach,
      canEdit: item.can_edit,
      canDelete: item.can_delete,
      canComplete: item.can_complete,
      isVisible: item.is_visible,
      hasSubtasks: item.has_subtasks,
      subtasksCount: item.subtasks_count,
      subtasksCompletedCount: item.subtasks_completed_count,
      subtaskCompletionPercentage: item.subtask_completion_percentage,
      createdAt: formatter.date(from: item.created_at) ?? Date(),
      updatedAt: formatter.date(from: item.updated_at) ?? Date()
    )
  }

  private func convertTaskItemToItem(_ taskItem: TaskItem) -> Item {
    return Item(
      id: taskItem.id,
      list_id: taskItem.listId,
      title: taskItem.title,
      description: taskItem.itemDescription,
      due_at: taskItem.dueAt?.ISO8601Format(),
      completed_at: taskItem.completedAt?.ISO8601Format(),
      priority: taskItem.priority,
      can_be_snoozed: taskItem.canBeSnoozed,
      notification_interval_minutes: taskItem.notificationIntervalMinutes,
      requires_explanation_if_missed: taskItem.requiresExplanationIfMissed,
      overdue: taskItem.overdue,
      minutes_overdue: taskItem.minutesOverdue,
      requires_explanation: taskItem.requiresExplanation,
      is_recurring: taskItem.isRecurring,
      recurrence_pattern: taskItem.recurrencePattern,
      recurrence_interval: taskItem.recurrenceInterval,
      recurrence_days: taskItem.recurrenceDays,
      location_based: taskItem.locationBased,
      location_name: taskItem.locationName,
      location_latitude: taskItem.locationLatitude,
      location_longitude: taskItem.locationLongitude,
      location_radius_meters: taskItem.locationRadiusMeters,
      notify_on_arrival: taskItem.notifyOnArrival,
      notify_on_departure: taskItem.notifyOnDeparture,
      missed_reason: taskItem.missedReason,
      missed_reason_submitted_at: taskItem.missedReasonSubmittedAt?.ISO8601Format(),
      missed_reason_reviewed_at: taskItem.missedReasonReviewedAt?.ISO8601Format(),
      creator: UserDTO(
        id: taskItem.creator?.id ?? 0,
        email: taskItem.creator?.email ?? "",
        name: taskItem.creator?.name ?? "",
        role: taskItem.creator?.role ?? "client",
        timezone: taskItem.creator?.timezone
      ),
      created_by_coach: taskItem.createdByCoach,
      can_edit: taskItem.canEdit,
      can_delete: taskItem.canDelete,
      can_complete: taskItem.canComplete,
      is_visible: taskItem.isVisible,
      escalation: taskItem.escalation != nil ? Escalation(
        id: taskItem.escalation!.id,
        level: taskItem.escalation!.level,
        notification_count: taskItem.escalation!.notificationCount,
        blocking_app: taskItem.escalation!.blockingApp,
        coaches_notified: taskItem.escalation!.coachesNotified,
        became_overdue_at: taskItem.escalation!.becameOverdueAt?.ISO8601Format(),
        last_notification_at: taskItem.escalation!.lastNotificationAt?.ISO8601Format()
      ) : nil,
      has_subtasks: taskItem.hasSubtasks,
      subtasks_count: taskItem.subtasksCount,
      subtasks_completed_count: taskItem.subtasksCompletedCount,
      subtask_completion_percentage: taskItem.subtaskCompletionPercentage,
      created_at: taskItem.createdAt.ISO8601Format(),
      updated_at: taskItem.updatedAt.ISO8601Format()
    )
  }
}
