import Foundation
import SwiftData
import Combine

/// SyncCoordinator - Coordinates synchronization across all services
/// Replaces the old DeltaSyncService with a simpler approach using existing service sync methods
@MainActor
final class SyncCoordinator: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var syncError: Error?

    private let itemService: ItemService
    private let listService: ListService
    private let swiftDataManager: SwiftDataManager

    init(itemService: ItemService, listService: ListService, swiftDataManager: SwiftDataManager) {
        self.itemService = itemService
        self.listService = listService
        self.swiftDataManager = swiftDataManager
    }

    /// Perform full sync of all data
    func syncAll() async throws {
        print("🔄 SyncCoordinator: Starting full sync...")
        isSyncing = true
        syncError = nil

        do {
            // Sync lists first
            try await syncLists()

            // Then sync items for each list
            try await syncAllItems()

            lastSyncTime = Date()
            print("✅ SyncCoordinator: Full sync completed successfully")
        } catch {
            syncError = error
            print("❌ SyncCoordinator: Full sync failed: \(error)")
            throw error
        }

        isSyncing = false
    }

    /// Sync all lists
    private func syncLists() async throws {
        print("🔄 SyncCoordinator: Syncing lists...")

        let lists = try await listService.fetchLists()

        // Convert to SwiftData models and save
        for listDTO in lists {
            let list = List(
                id: listDTO.id,
                name: listDTO.name,
                description: listDTO.description ?? "",
                role: "owner",
                tasksCount: 0,
                overdueTasksCount: 0,
                createdAt: ISO8601DateFormatter().date(from: listDTO.created_at) ?? Date(),
                updatedAt: ISO8601DateFormatter().date(from: listDTO.updated_at) ?? Date()
            )

            // Check if list already exists
            let fetchDescriptor = FetchDescriptor<List>(
                predicate: #Predicate<List> { $0.id == listDTO.id }
            )

            if let existing = try? swiftDataManager.context.fetch(fetchDescriptor).first {
                // Update existing
                existing.name = list.name
                existing.itemDescription = list.itemDescription
                existing.updatedAt = list.updatedAt
            } else {
                // Insert new
                swiftDataManager.context.insert(list)
            }
        }

        try? swiftDataManager.context.save()
        print("✅ SyncCoordinator: Synced \(lists.count) lists")
    }

    /// Sync items for all lists
    private func syncAllItems() async throws {
        print("🔄 SyncCoordinator: Syncing all items...")

        // Get all lists
        let lists = try await listService.fetchLists()

        var totalItems = 0
        for list in lists {
            do {
                try await itemService.syncItemsForList(listId: list.id)

                // Count items for this list
                let fetchDescriptor = FetchDescriptor<TaskItem>(
                    predicate: #Predicate<TaskItem> { $0.listId == list.id }
                )
                if let items = try? swiftDataManager.context.fetch(fetchDescriptor) {
                    totalItems += items.count
                }
            } catch {
                print("⚠️ SyncCoordinator: Failed to sync items for list \(list.id): \(error)")
                // Continue with other lists even if one fails
            }
        }

        print("✅ SyncCoordinator: Synced \(totalItems) total items across \(lists.count) lists")
    }

    /// Sync items for a specific list
    func syncList(id: Int) async throws {
        print("🔄 SyncCoordinator: Syncing list \(id)...")
        isSyncing = true
        syncError = nil

        do {
            try await itemService.syncItemsForList(listId: id)
            lastSyncTime = Date()
            print("✅ SyncCoordinator: List \(id) synced successfully")
        } catch {
            syncError = error
            print("❌ SyncCoordinator: List \(id) sync failed: \(error)")
            throw error
        }

        isSyncing = false
    }
}
