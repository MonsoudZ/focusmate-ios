import Foundation
import SwiftData
import Combine

@MainActor
final class DeltaSyncService: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    private let apiClient: APIClient
    private let swiftDataManager: SwiftDataManager
    
    init(apiClient: APIClient, swiftDataManager: SwiftDataManager) {
        self.apiClient = apiClient
        self.swiftDataManager = swiftDataManager
    }
    
    // MARK: - Delta Sync Methods
    
    func syncUsers() async throws {
        print("🔄 DeltaSyncService: Starting user sync...")
        
        let parameters = swiftDataManager.getDeltaSyncParameters(for: "users")
        let users: [UserDTO] = try await apiClient.request("GET", "users", body: nil as String?, queryParameters: parameters)
        
        // Convert DTOs to SwiftData models and save
        let context = swiftDataManager.context
        var swiftDataUsers: [User] = []
        
        for userDTO in users {
            // Check if user already exists
            let fetchDescriptor = FetchDescriptor<User>(
                predicate: #Predicate { $0.id == userDTO.id }
            )
            
            let existingUsers = try? context.fetch(fetchDescriptor)
            let existingUser = existingUsers?.first
            
            if let existing = existingUser {
                // Update existing user
                existing.email = userDTO.email
                existing.name = userDTO.name
                existing.role = userDTO.role
                existing.timezone = userDTO.timezone
                if let createdAt = userDTO.created_at {
                    existing.createdAt = ISO8601DateFormatter().date(from: createdAt)
                }
                swiftDataUsers.append(existing)
            } else {
                // Create new user
                let user = User(
                    id: userDTO.id,
                    email: userDTO.email,
                    name: userDTO.name,
                    role: userDTO.role,
                    timezone: userDTO.timezone,
                    createdAt: userDTO.created_at != nil ? ISO8601DateFormatter().date(from: userDTO.created_at!) : nil
                )
                context.insert(user)
                swiftDataUsers.append(user)
            }
        }
        
        swiftDataManager.markEntitiesAsSynced(swiftDataUsers, entityType: "users")
        print("✅ DeltaSyncService: User sync completed")
    }
    
    func syncLists() async throws {
        print("🔄 DeltaSyncService: Starting list sync...")
        
        let parameters = swiftDataManager.getDeltaSyncParameters(for: "lists")
        let lists: [ListDTO] = try await apiClient.request("GET", "lists", body: nil as String?, queryParameters: parameters)
        
        let context = swiftDataManager.context
        var swiftDataLists: [List] = []
        
        for listDTO in lists {
            // Check if list already exists
            let fetchDescriptor = FetchDescriptor<List>(
                predicate: #Predicate { $0.id == listDTO.id }
            )
            
            let existingLists = try? context.fetch(fetchDescriptor)
            let existingList = existingLists?.first
            
            if let existing = existingList {
                // Update existing list
                existing.name = listDTO.name
                existing.itemDescription = listDTO.description
                existing.role = listDTO.role
                existing.tasksCount = listDTO.tasksCount
                existing.overdueTasksCount = listDTO.overdueTasksCount
                existing.updatedAt = listDTO.updatedAt
                swiftDataLists.append(existing)
            } else {
                // Create new list
                let list = List(
                    id: listDTO.id,
                    name: listDTO.name,
                    description: listDTO.description,
                    role: listDTO.role,
                    tasksCount: listDTO.tasksCount,
                    overdueTasksCount: listDTO.overdueTasksCount,
                    createdAt: listDTO.createdAt,
                    updatedAt: listDTO.updatedAt
                )
                
                // Set owner relationship
                let ownerFetchDescriptor = FetchDescriptor<User>(
                    predicate: #Predicate { $0.id == listDTO.owner.id }
                )
                if let owner = try? context.fetch(ownerFetchDescriptor).first {
                    list.owner = owner
                }
                
                context.insert(list)
                swiftDataLists.append(list)
            }
        }
        
        swiftDataManager.markEntitiesAsSynced(swiftDataLists, entityType: "lists")
        print("✅ DeltaSyncService: List sync completed")
    }
    
    func syncItems(for listId: Int? = nil) async throws {
        print("🔄 DeltaSyncService: Starting item sync...")
        
        let parameters = swiftDataManager.getDeltaSyncParameters(for: "items")
        var queryParams = parameters
        
        let items: [Item]
        
        if let listId = listId {
            // Try nested endpoint first: lists/{listId}/tasks
            do {
                print("🔄 DeltaSyncService: Trying GET lists/\(listId)/tasks")
                items = try await apiClient.request("GET", "lists/\(listId)/tasks", body: nil as String?, queryParameters: parameters)
                print("✅ DeltaSyncService: Fetched \(items.count) items from nested endpoint for list \(listId)")
            } catch let error {
                print("❌ DeltaSyncService: Nested endpoint failed with error: \(error)")
                print("🔄 DeltaSyncService: Trying tasks endpoint with query params")
                queryParams["list_id"] = String(listId)
                do {
                    items = try await apiClient.request("GET", "tasks", body: nil as String?, queryParameters: queryParams)
                    print("✅ DeltaSyncService: Fetched \(items.count) items from tasks endpoint")
                } catch let fallbackError {
                    print("❌ DeltaSyncService: Tasks endpoint also failed: \(fallbackError)")
                    // Return empty array instead of throwing to allow app to continue
                    items = []
                }
            }
        } else {
            items = try await apiClient.request("GET", "tasks", body: nil as String?, queryParameters: queryParams)
        }
        
        let context = swiftDataManager.context
        var swiftDataItems: [TaskItem] = []
        
        for itemDTO in items {
            // Check if item already exists
            let fetchDescriptor = FetchDescriptor<TaskItem>(
                predicate: #Predicate { $0.id == itemDTO.id }
            )
            
            let existingItems = try? context.fetch(fetchDescriptor)
            let existingItem = existingItems?.first
            
            if let existing = existingItem {
                // Update existing item
                updateItemFromDTO(existing, from: itemDTO)
                swiftDataItems.append(existing)
            } else {
                // Create new item
                let item = createItemFromDTO(itemDTO, context: context)
                context.insert(item)
                swiftDataItems.append(item)
            }
        }
        
        swiftDataManager.markEntitiesAsSynced(swiftDataItems, entityType: "items")
        print("✅ DeltaSyncService: Item sync completed")
    }
    
    func syncAll() async throws {
        print("🔄 DeltaSyncService: Starting full sync...")
        
        swiftDataManager.updateSyncStatus(isOnline: true, syncInProgress: true)
        
        do {
            try await syncUsers()
            try await syncLists()
            try await syncItems()
            
            swiftDataManager.updateSyncStatus(isOnline: true, syncInProgress: false, pendingChanges: 0)
            print("✅ DeltaSyncService: Full sync completed successfully")
        } catch {
            swiftDataManager.updateSyncStatus(isOnline: false, syncInProgress: false)
            print("❌ DeltaSyncService: Full sync failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    private func createItemFromDTO(_ dto: Item, context: ModelContext) -> TaskItem {
                let item = TaskItem(
            id: dto.id,
            listId: dto.list_id,
            title: dto.title,
            description: dto.description,
            dueAt: dto.dueDate,
            completedAt: dto.completed_at != nil ? ISO8601DateFormatter().date(from: dto.completed_at!) : nil,
            priority: dto.priority,
            canBeSnoozed: dto.can_be_snoozed,
            notificationIntervalMinutes: dto.notification_interval_minutes,
            requiresExplanationIfMissed: dto.requires_explanation_if_missed,
            overdue: dto.overdue,
            minutesOverdue: dto.minutes_overdue,
            requiresExplanation: dto.requires_explanation,
            isRecurring: dto.is_recurring,
            recurrencePattern: dto.recurrence_pattern,
            recurrenceInterval: dto.recurrence_interval,
            recurrenceDays: dto.recurrence_days,
            locationBased: dto.location_based,
            locationName: dto.location_name,
            locationLatitude: dto.location_latitude,
            locationLongitude: dto.location_longitude,
            locationRadiusMeters: dto.location_radius_meters,
            notifyOnArrival: dto.notify_on_arrival,
            notifyOnDeparture: dto.notify_on_departure,
            missedReason: dto.missed_reason,
            missedReasonSubmittedAt: dto.missed_reason_submitted_at != nil ? ISO8601DateFormatter().date(from: dto.missed_reason_submitted_at!) : nil,
            missedReasonReviewedAt: dto.missed_reason_reviewed_at != nil ? ISO8601DateFormatter().date(from: dto.missed_reason_reviewed_at!) : nil,
            createdByCoach: dto.created_by_coach,
            canEdit: dto.can_edit,
            canDelete: dto.can_delete,
            canComplete: dto.can_complete,
            isVisible: dto.is_visible,
            hasSubtasks: dto.has_subtasks,
            subtasksCount: dto.subtasks_count,
            subtasksCompletedCount: dto.subtasks_completed_count,
            subtaskCompletionPercentage: dto.subtask_completion_percentage,
            createdAt: ISO8601DateFormatter().date(from: dto.created_at) ?? Date(),
            updatedAt: ISO8601DateFormatter().date(from: dto.updated_at) ?? Date()
        )
        
        // Set relationships
        let creatorFetchDescriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.id == dto.creator.id }
        )
        if let creator = try? context.fetch(creatorFetchDescriptor).first {
            item.creator = creator
        }
        
        let listFetchDescriptor = FetchDescriptor<List>(
            predicate: #Predicate { $0.id == dto.list_id }
        )
        if let list = try? context.fetch(listFetchDescriptor).first {
            item.list = list
        }
        
        // Handle escalation if present
        if let escalationDTO = dto.escalation {
            let escalation = TaskEscalation(
                id: escalationDTO.id,
                level: escalationDTO.level,
                notificationCount: escalationDTO.notification_count,
                blockingApp: escalationDTO.blocking_app,
                coachesNotified: escalationDTO.coaches_notified,
                becameOverdueAt: escalationDTO.became_overdue_at != nil ? ISO8601DateFormatter().date(from: escalationDTO.became_overdue_at!) : nil,
                lastNotificationAt: escalationDTO.last_notification_at != nil ? ISO8601DateFormatter().date(from: escalationDTO.last_notification_at!) : nil
            )
            item.escalation = escalation
            context.insert(escalation)
        }
        
        return item
    }
    
    private func updateItemFromDTO(_ item: TaskItem, from dto: Item) {
        item.title = dto.title
        item.itemDescription = dto.description
        item.dueAt = dto.dueDate
        item.completedAt = dto.completed_at != nil ? ISO8601DateFormatter().date(from: dto.completed_at!) : nil
        item.priority = dto.priority
        item.canBeSnoozed = dto.can_be_snoozed
        item.notificationIntervalMinutes = dto.notification_interval_minutes
        item.requiresExplanationIfMissed = dto.requires_explanation_if_missed
        item.overdue = dto.overdue
        item.minutesOverdue = dto.minutes_overdue
        item.requiresExplanation = dto.requires_explanation
        item.isRecurring = dto.is_recurring
        item.recurrencePattern = dto.recurrence_pattern
        item.recurrenceInterval = dto.recurrence_interval
        item.recurrenceDays = dto.recurrence_days
        item.locationBased = dto.location_based
        item.locationName = dto.location_name
        item.locationLatitude = dto.location_latitude
        item.locationLongitude = dto.location_longitude
        item.locationRadiusMeters = dto.location_radius_meters
        item.notifyOnArrival = dto.notify_on_arrival
        item.notifyOnDeparture = dto.notify_on_departure
        item.missedReason = dto.missed_reason
        item.missedReasonSubmittedAt = dto.missed_reason_submitted_at != nil ? ISO8601DateFormatter().date(from: dto.missed_reason_submitted_at!) : nil
        item.missedReasonReviewedAt = dto.missed_reason_reviewed_at != nil ? ISO8601DateFormatter().date(from: dto.missed_reason_reviewed_at!) : nil
        item.createdByCoach = dto.created_by_coach
        item.canEdit = dto.can_edit
        item.canDelete = dto.can_delete
        item.canComplete = dto.can_complete
        item.isVisible = dto.is_visible
        item.hasSubtasks = dto.has_subtasks
        item.subtasksCount = dto.subtasks_count
        item.subtasksCompletedCount = dto.subtasks_completed_count
        item.subtaskCompletionPercentage = dto.subtask_completion_percentage
        item.updatedAt = ISO8601DateFormatter().date(from: dto.updated_at) ?? Date()
    }
}

// MARK: - APIClient Extension for Query Parameters

extension APIClient {
    func request<T: Decodable, B: Encodable>(
        _ method: String,
        _ path: String,
        body: B? = nil,
        queryParameters: [String: String] = [:]
    ) async throws -> T {
        var url = Endpoints.path(path)
        
        // Add query parameters
        if !queryParameters.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = queryParameters.map { URLQueryItem(name: $0.key, value: $0.value) }
            if let newURL = components?.url {
                url = newURL
            }
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let b = body {
            req.httpBody = try APIClient.encoder.encode(b)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("ngrok-skip-browser-warning", forHTTPHeaderField: "ngrok-skip-browser-warning")
        
        if let jwt = getToken() {
            req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, resp) = try await getSession().data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw APIError.badURL }
            switch http.statusCode {
            case 200...299:
                break
            case 401:
                throw APIError.unauthorized
            default:
                let bodyPreview = String(data: data, encoding: .utf8) ?? "<non-utf8>"
                print("⚠️ APIClient: bad status \(http.statusCode) for \(method) \(url.absoluteString) body=\(bodyPreview)")
                throw APIError.badStatus(http.statusCode, nil, nil)
            }
            
            if data.isEmpty {
                if T.self == EmptyResponse.self {
                    return EmptyResponse() as! T
                } else {
                    print("🧩 APIClient: Expected \(T.self) but got empty response")
                    throw APIError.decoding
                }
            }
            
            let result = try APIClient.railsAPI.decode(T.self, from: data)
            return result
        } catch {
            if let apiError = error as? APIError { throw apiError }
            throw APIError.network(error)
        }
    }
}
