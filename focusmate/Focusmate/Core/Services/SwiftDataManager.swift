import Combine
import Foundation
import SwiftData
import SwiftUI

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
      SyncStatus.self,
    ])

    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    do {
      self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
      self.modelContext = self.modelContainer.mainContext

      // Initialize or get existing sync status
      let fetchDescriptor = FetchDescriptor<SyncStatus>()
      let existingStatus = try? self.modelContext.fetch(fetchDescriptor).first

      if let existing = existingStatus {
        self.syncStatus = existing
      } else {
        self.syncStatus = SyncStatus()
        self.modelContext.insert(self.syncStatus)
        try? self.modelContext.save()
      }

      Logger.info("SwiftData initialized successfully", category: .database)
      self.isInitialized = true

    } catch {
      // Graceful degradation: Use in-memory storage as fallback
      Logger.error("Failed to create persistent ModelContainer, falling back to in-memory storage", error: error, category: .database)

      // Report to Sentry
      SentryService.shared.captureError(error, context: ["source": "swiftdata_init", "fallback": "in_memory"])

      // Create in-memory container as fallback
      let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

      do {
        self.modelContainer = try ModelContainer(for: schema, configurations: [inMemoryConfig])
        self.modelContext = self.modelContainer.mainContext

        // Initialize sync status for in-memory store
        self.syncStatus = SyncStatus()
        self.modelContext.insert(self.syncStatus)
        try? self.modelContext.save()

        Logger.warning("Using in-memory storage - data will not persist", category: .database)
        self.isInitialized = true

        // Show user notification about degraded mode
        Task { @MainActor in
          self.notifyUserOfDegradedStorage()
        }

      } catch {
        // If even in-memory fails, this is critical
        Logger.error("Critical: Failed to create even in-memory ModelContainer", error: error, category: .database)
        SentryService.shared.captureError(error, context: ["source": "swiftdata_init_fallback_failed"])

        // Create minimal SyncStatus to prevent crashes
        self.syncStatus = SyncStatus()

        // Last resort: Create a dummy container that won't be used
        // This prevents the app from crashing, but features will be limited
        fatalError("Critical: SwiftData initialization completely failed. Cannot continue.")
      }
    }
  }

  private func notifyUserOfDegradedStorage() {
    // Post notification for UI to show alert
    NotificationCenter.default.post(
      name: .showDegradedStorageWarning,
      object: nil
    )
  }

  // MARK: - Public Access

  var context: ModelContext {
    self.modelContext
  }

  // MARK: - Sync Management

  func updateSyncStatus(isOnline: Bool, syncInProgress: Bool = false, pendingChanges: Int = 0) {
    self.syncStatus.isOnline = isOnline
    self.syncStatus.syncInProgress = syncInProgress
    self.syncStatus.pendingChanges = pendingChanges

    if syncInProgress {
      self.syncStatus.lastSyncAttempt = Date()
    }

    if !syncInProgress, isOnline {
      self.syncStatus.lastSuccessfulSync = Date()
    }

    try? self.modelContext.save()
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
      self.modelContext.insert(metadata)
    }

    try? self.modelContext.save()
  }

  // MARK: - Entity Management

  func saveContext() {
    do {
      try self.modelContext.save()
    } catch {
      Logger.error("SwiftDataManager: Failed to save context: \(error)", category: .database)
    }
  }

  func deleteAllData() {
    Logger.debug("🧹 SwiftDataManager: Deleting all cached data", category: .database)

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

      for user in users {
        self.modelContext.delete(user)
      }
      for list in lists {
        self.modelContext.delete(list)
      }
      for item in items {
        self.modelContext.delete(item)
      }
      for escalation in escalations {
        self.modelContext.delete(escalation)
      }
      for coachShare in coachShares {
        self.modelContext.delete(coachShare)
      }
      for meta in metadata {
        self.modelContext.delete(meta)
      }

      // Reset sync timestamps to force full sync
      self.syncStatus.lastSuccessfulSync = nil
      self.syncStatus.lastSyncAttempt = nil

      try self.modelContext.save()
      Logger.info("SwiftDataManager: All cached data deleted and sync timestamps reset", category: .database)
    } catch {
      Logger.error("SwiftDataManager: Failed to delete all data: \(error)", category: .database)
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

  func markEntitiesAsSynced(_ entities: [some PersistentModel], entityType: String) {
    let now = Date()
    self.updateLastSyncTimestamp(for: entityType, timestamp: now)

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

    self.saveContext()
  }
}
