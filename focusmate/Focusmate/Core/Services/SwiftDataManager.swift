import Foundation
import SwiftData
import SwiftUI
import Combine

@MainActor
final class SwiftDataManager: ObservableObject {
    static let shared = SwiftDataManager()
    
    var modelContainer: ModelContainer
    private var modelContext: ModelContext
    
    @Published var syncStatus: SyncStatus
    @Published var isInitialized = false
    
    private init() {
        // Create the model container with all our SwiftData models
        let schema = Schema([
            User.self,
            List.self,
            TaskCoachShare.self,
            TaskItem.self,
            TaskEscalation.self,
            SyncMetadata.self,
            SyncStatus.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            modelContext = modelContainer.mainContext
            
            // Initialize or get existing sync status
            let fetchDescriptor = FetchDescriptor<SyncStatus>()
            let existingStatus = try? modelContext.fetch(fetchDescriptor).first
            
            if let existing = existingStatus {
                syncStatus = existing
            } else {
                syncStatus = SyncStatus()
                modelContext.insert(syncStatus)
                try? modelContext.save()
            }
            
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    // MARK: - Public Access
    
    var context: ModelContext {
        modelContext
    }
    
    // MARK: - Sync Management
    
    func updateSyncStatus(isOnline: Bool, syncInProgress: Bool = false, pendingChanges: Int = 0) {
        syncStatus.isOnline = isOnline
        syncStatus.syncInProgress = syncInProgress
        syncStatus.pendingChanges = pendingChanges
        
        if syncInProgress {
            syncStatus.lastSyncAttempt = Date()
        }
        
        if !syncInProgress && isOnline {
            syncStatus.lastSuccessfulSync = Date()
        }
        
        try? modelContext.save()
    }
    
    func getLastSyncTimestamp(for entityType: String) -> Date? {
        let fetchDescriptor = FetchDescriptor<SyncMetadata>(
            predicate: #Predicate { $0.entityType == entityType }
        )
        
        guard let metadata = try? modelContext.fetch(fetchDescriptor).first else {
            return nil
        }
        
        return metadata.lastSyncTimestamp
    }
    
    func updateLastSyncTimestamp(for entityType: String, timestamp: Date, since: String? = nil) {
        let fetchDescriptor = FetchDescriptor<SyncMetadata>(
            predicate: #Predicate { $0.entityType == entityType }
        )
        
        if let existing = try? modelContext.fetch(fetchDescriptor).first {
            existing.lastSyncTimestamp = timestamp
            existing.lastSyncSince = since
        } else {
            let metadata = SyncMetadata(entityType: entityType, lastSyncTimestamp: timestamp, lastSyncSince: since)
            modelContext.insert(metadata)
        }
        
        try? modelContext.save()
    }
    
    // MARK: - Entity Management
    
    func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("❌ SwiftDataManager: Failed to save context: \(error)")
        }
    }
    
    func deleteAllData() {
        // Delete all entities
        let userDescriptor = FetchDescriptor<User>()
        let listDescriptor = FetchDescriptor<List>()
        let itemDescriptor = FetchDescriptor<TaskItem>()
        let escalationDescriptor = FetchDescriptor<TaskEscalation>()
        let coachShareDescriptor = FetchDescriptor<TaskCoachShare>()
        let metadataDescriptor = FetchDescriptor<SyncMetadata>()
        
        do {
            let users = try modelContext.fetch(userDescriptor)
            let lists = try modelContext.fetch(listDescriptor)
            let items = try modelContext.fetch(itemDescriptor)
            let escalations = try modelContext.fetch(escalationDescriptor)
            let coachShares = try modelContext.fetch(coachShareDescriptor)
            let metadata = try modelContext.fetch(metadataDescriptor)
            
            for user in users { modelContext.delete(user) }
            for list in lists { modelContext.delete(list) }
            for item in items { modelContext.delete(item) }
            for escalation in escalations { modelContext.delete(escalation) }
            for coachShare in coachShares { modelContext.delete(coachShare) }
            for meta in metadata { modelContext.delete(meta) }
            
            try modelContext.save()
            print("✅ SwiftDataManager: All data deleted")
        } catch {
            print("❌ SwiftDataManager: Failed to delete all data: \(error)")
        }
    }
    
    // MARK: - Delta Sync Helpers
    
    func getDeltaSyncParameters(for entityType: String) -> [String: String] {
        var parameters: [String: String] = [:]
        
        if let lastSync = getLastSyncTimestamp(for: entityType) {
            let formatter = ISO8601DateFormatter()
            parameters["since"] = formatter.string(from: lastSync)
        }
        
        return parameters
    }
    
    func markEntitiesAsSynced<T: PersistentModel>(_ entities: [T], entityType: String) {
        let now = Date()
        updateLastSyncTimestamp(for: entityType, timestamp: now)
        
        // Update lastSyncAt for each entity
        for entity in entities {
            if let user = entity as? User {
                user.lastSyncAt = now
            } else if let list = entity as? List {
                list.lastSyncAt = now
            } else if let item = entity as? TaskItem {
                item.lastSyncAt = now
            } else if let escalation = entity as? TaskEscalation {
                escalation.lastSyncAt = now
            } else if let coachShare = entity as? TaskCoachShare {
                coachShare.lastSyncAt = now
            }
        }
        
        saveContext()
    }
}
