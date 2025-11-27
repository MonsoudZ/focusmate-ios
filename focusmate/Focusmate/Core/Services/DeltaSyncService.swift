import Foundation
import SwiftData
import Combine

/// DeltaSyncService - Handles synchronization between local SwiftData and remote API
final class DeltaSyncService: ObservableObject {
    let objectWillChange = PassthroughSubject<Void, Never>()
    
    private let apiClient: NewAPIClient
    private let swiftDataManager: SwiftDataManager
    private let authSession: AuthSession
    
    init(apiClient: NewAPIClient, swiftDataManager: SwiftDataManager, authSession: AuthSession) {
        self.apiClient = apiClient
        self.swiftDataManager = swiftDataManager
        self.authSession = authSession
    }

    func syncAll() async throws {
        #if DEBUG
        print("🔄 DeltaSyncService: Starting full sync...")
        #endif
        try await syncUsers()
        try await syncLists()
        try await syncItems()
        #if DEBUG
        print("✅ DeltaSyncService: Full sync completed")
        #endif
    }

    func syncUsers() async throws {
        #if DEBUG
        print("🔄 DeltaSyncService: Syncing users...")
        #endif
        // For now, just mark as completed since we don't have a users endpoint
        #if DEBUG
        print("✅ DeltaSyncService: Users sync completed (no-op)")
        #endif
    }

    func syncLists() async throws {
        #if DEBUG
        print("🔄 DeltaSyncService: Syncing lists...")
        #endif
        
        let listsRepo = ListsRepo(api: apiClient)
        let page: Page<ListDTO> = try await listsRepo.index()
        
        // Convert DTOs to SwiftData models and save
        for listDTO in page.data {
            let list = List(
                id: listDTO.id,
                name: listDTO.title,
                description: listDTO.description ?? "",
                role: "owner", // Default role
                tasksCount: 0, // Will be updated when items are synced
                overdueTasksCount: 0, // Will be updated when items are synced
                createdAt: Date(),
                updatedAt: ISO8601DateFormatter().date(from: listDTO.updated_at) ?? Date()
            )
            
            try swiftDataManager.context.insert(list)
        }
        
        try swiftDataManager.context.save()
        #if DEBUG
        print("✅ DeltaSyncService: Lists sync completed - \(page.data.count) lists")
        #endif
    }

    func syncItems(for listId: Int? = nil) async throws {
        #if DEBUG
        print("🔄 DeltaSyncService: Syncing items...")
        #endif
        
        let tasksRepo = TasksRepo(api: apiClient)
        
        if let listId = listId {
            // Sync items for specific list
            let page: Page<TaskDTO> = try await tasksRepo.index(listId: listId)
            await processTaskDTOs(page.data, listId: listId)
        } else {
            // Sync all items (this would need to be implemented based on API)
            #if DEBUG
            print("⚠️ DeltaSyncService: Syncing all items not yet implemented")
            #endif
        }
        
        #if DEBUG
        print("✅ DeltaSyncService: Items sync completed")
        #endif
    }
    
    private func processTaskDTOs(_ taskDTOs: [TaskDTO], listId: Int) async {
        for taskDTO in taskDTOs {
            let item = TaskItem(
                id: taskDTO.id,
                listId: listId,
                title: taskDTO.title,
                description: taskDTO.notes,
                dueAt: nil, // Not available in TaskDTO
                completedAt: taskDTO.completed_at.flatMap { ISO8601DateFormatter().date(from: $0) },
                priority: 1, // Default priority
                canBeSnoozed: true,
                notificationIntervalMinutes: 15,
                requiresExplanationIfMissed: false,
                overdue: false,
                minutesOverdue: 0,
                requiresExplanation: false,
                isRecurring: false,
                recurrencePattern: nil,
                recurrenceInterval: 0,
                recurrenceDays: nil,
                locationBased: false,
                locationName: nil,
                locationLatitude: nil,
                locationLongitude: nil,
                locationRadiusMeters: 0,
                notifyOnArrival: false,
                notifyOnDeparture: false,
                missedReason: nil,
                missedReasonSubmittedAt: nil,
                missedReasonReviewedAt: nil,
                createdByCoach: false,
                canEdit: true,
                canDelete: true,
                canComplete: true,
                isVisible: true,
                hasSubtasks: false,
                subtasksCount: 0,
                subtasksCompletedCount: 0,
                subtaskCompletionPercentage: 0,
                createdAt: Date(),
                updatedAt: taskDTO.updated_at.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
            )
            
            try? swiftDataManager.context.insert(item)
        }
        
        try? swiftDataManager.context.save()
    }
}