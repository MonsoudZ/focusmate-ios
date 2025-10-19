import Foundation
import SwiftData
import SwiftUI

// MARK: - SwiftData Models

@Model
final class User {
    @Attribute(.unique) var id: Int
    var email: String
    var name: String?
    var role: String
    var timezone: String?
    var createdAt: Date?
    var lastSyncAt: Date?
    
    init(id: Int, email: String, name: String?, role: String, timezone: String?, createdAt: Date?) {
        self.id = id
        self.email = email
        self.name = name
        self.role = role
        self.timezone = timezone
        self.createdAt = createdAt
        self.lastSyncAt = Date()
    }
    
    var isCoach: Bool {
        role == "coach"
    }
    
    var isClient: Bool {
        role == "client"
    }
}

@Model
final class List {
    @Attribute(.unique) var id: Int
    var name: String
    var itemDescription: String?
    var role: String
    var tasksCount: Int
    var overdueTasksCount: Int
    var createdAt: Date
    var updatedAt: Date
    var lastSyncAt: Date?
    
    // Relationships
    @Relationship(deleteRule: .cascade) var owner: User?
    @Relationship(deleteRule: .cascade) var sharedWithCoaches: [TaskCoachShare] = []
    @Relationship(deleteRule: .cascade) var items: [TaskItem] = []
    
    init(id: Int, name: String, description: String?, role: String, tasksCount: Int, overdueTasksCount: Int, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.itemDescription = description
        self.role = role
        self.tasksCount = tasksCount
        self.overdueTasksCount = overdueTasksCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastSyncAt = Date()
    }
}

@Model
final class TaskCoachShare {
    @Attribute(.unique) var id: Int
    var permissions: [String]
    var lastSyncAt: Date?
    
    // Relationships
    @Relationship(deleteRule: .nullify) var coach: User?
    @Relationship(deleteRule: .nullify) var list: List?
    
    init(id: Int, permissions: [String]) {
        self.id = id
        self.permissions = permissions
        self.lastSyncAt = Date()
    }
}

@Model
final class TaskItem {
    @Attribute(.unique) var id: Int
    var listId: Int
    var title: String
    var itemDescription: String?
    var dueAt: Date?
    var completedAt: Date?
    var priority: Int
    var canBeSnoozed: Bool
    var notificationIntervalMinutes: Int
    var requiresExplanationIfMissed: Bool
    
    // Status
    var overdue: Bool
    var minutesOverdue: Int
    var requiresExplanation: Bool
    
    // Recurring
    var isRecurring: Bool
    var recurrencePattern: String?
    var recurrenceInterval: Int
    var recurrenceDays: [Int]?
    
    // Location
    var locationBased: Bool
    var locationName: String?
    var locationLatitude: Double?
    var locationLongitude: Double?
    var locationRadiusMeters: Int
    var notifyOnArrival: Bool
    var notifyOnDeparture: Bool
    
    // Accountability
    var missedReason: String?
    var missedReasonSubmittedAt: Date?
    var missedReasonReviewedAt: Date?
    
    // Creator
    var createdByCoach: Bool
    
    // Permissions
    var canEdit: Bool
    var canDelete: Bool
    var canComplete: Bool
    
    // Visibility
    var isVisible: Bool
    
    // Subtasks
    var hasSubtasks: Bool
    var subtasksCount: Int
    var subtasksCompletedCount: Int
    var subtaskCompletionPercentage: Int
    
    // Timestamps
    var createdAt: Date
    var updatedAt: Date
    var lastSyncAt: Date?
    
    // Relationships
    @Relationship(deleteRule: .nullify) var creator: User?
    @Relationship(deleteRule: .nullify) var list: List?
    @Relationship(deleteRule: .cascade) var escalation: TaskEscalation?
    
    init(id: Int, listId: Int, title: String, description: String?, dueAt: Date?, completedAt: Date?, priority: Int, canBeSnoozed: Bool, notificationIntervalMinutes: Int, requiresExplanationIfMissed: Bool, overdue: Bool, minutesOverdue: Int, requiresExplanation: Bool, isRecurring: Bool, recurrencePattern: String?, recurrenceInterval: Int, recurrenceDays: [Int]?, locationBased: Bool, locationName: String?, locationLatitude: Double?, locationLongitude: Double?, locationRadiusMeters: Int, notifyOnArrival: Bool, notifyOnDeparture: Bool, missedReason: String?, missedReasonSubmittedAt: Date?, missedReasonReviewedAt: Date?, createdByCoach: Bool, canEdit: Bool, canDelete: Bool, canComplete: Bool, isVisible: Bool, hasSubtasks: Bool, subtasksCount: Int, subtasksCompletedCount: Int, subtaskCompletionPercentage: Int, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.listId = listId
        self.title = title
        self.itemDescription = description
        self.dueAt = dueAt
        self.completedAt = completedAt
        self.priority = priority
        self.canBeSnoozed = canBeSnoozed
        self.notificationIntervalMinutes = notificationIntervalMinutes
        self.requiresExplanationIfMissed = requiresExplanationIfMissed
        self.overdue = overdue
        self.minutesOverdue = minutesOverdue
        self.requiresExplanation = requiresExplanation
        self.isRecurring = isRecurring
        self.recurrencePattern = recurrencePattern
        self.recurrenceInterval = recurrenceInterval
        self.recurrenceDays = recurrenceDays
        self.locationBased = locationBased
        self.locationName = locationName
        self.locationLatitude = locationLatitude
        self.locationLongitude = locationLongitude
        self.locationRadiusMeters = locationRadiusMeters
        self.notifyOnArrival = notifyOnArrival
        self.notifyOnDeparture = notifyOnDeparture
        self.missedReason = missedReason
        self.missedReasonSubmittedAt = missedReasonSubmittedAt
        self.missedReasonReviewedAt = missedReasonReviewedAt
        self.createdByCoach = createdByCoach
        self.canEdit = canEdit
        self.canDelete = canDelete
        self.canComplete = canComplete
        self.isVisible = isVisible
        self.hasSubtasks = hasSubtasks
        self.subtasksCount = subtasksCount
        self.subtasksCompletedCount = subtasksCompletedCount
        self.subtaskCompletionPercentage = subtaskCompletionPercentage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastSyncAt = Date()
    }
    
    // Computed properties for SwiftUI
    var isCompleted: Bool {
        completedAt != nil
    }
    
    var priorityColor: String {
        switch priority {
        case 3: return "red"
        case 2: return "orange"
        case 1: return "yellow"
        default: return "gray"
        }
    }
    
    var priorityLabel: String {
        switch priority {
        case 3: return "Urgent"
        case 2: return "High"
        case 1: return "Medium"
        default: return "Low"
        }
    }
    
    var isStrict: Bool {
        !canBeSnoozed
    }
}

@Model
final class TaskEscalation {
    @Attribute(.unique) var id: Int
    var level: String
    var notificationCount: Int
    var blockingApp: Bool
    var coachesNotified: Bool
    var becameOverdueAt: Date?
    var lastNotificationAt: Date?
    var lastSyncAt: Date?
    
    // Relationships
    @Relationship(deleteRule: .nullify) var item: TaskItem?
    
    init(id: Int, level: String, notificationCount: Int, blockingApp: Bool, coachesNotified: Bool, becameOverdueAt: Date?, lastNotificationAt: Date?) {
        self.id = id
        self.level = level
        self.notificationCount = notificationCount
        self.blockingApp = blockingApp
        self.coachesNotified = coachesNotified
        self.becameOverdueAt = becameOverdueAt
        self.lastNotificationAt = lastNotificationAt
        self.lastSyncAt = Date()
    }
}

@Model
final class SyncMetadata {
    @Attribute(.unique) var entityType: String
    var lastSyncTimestamp: Date
    var lastSyncSince: String?
    
    init(entityType: String, lastSyncTimestamp: Date, lastSyncSince: String? = nil) {
        self.entityType = entityType
        self.lastSyncTimestamp = lastSyncTimestamp
        self.lastSyncSince = lastSyncSince
    }
}

// MARK: - Sync Status Model
@Model
final class SyncStatus {
    @Attribute(.unique) var id: String = "sync_status"
    var isOnline: Bool
    var lastSyncAttempt: Date?
    var lastSuccessfulSync: Date?
    var pendingChanges: Int
    var syncInProgress: Bool
    
    init(isOnline: Bool = false, lastSyncAttempt: Date? = nil, lastSuccessfulSync: Date? = nil, pendingChanges: Int = 0, syncInProgress: Bool = false) {
        self.isOnline = isOnline
        self.lastSyncAttempt = lastSyncAttempt
        self.lastSuccessfulSync = lastSuccessfulSync
        self.pendingChanges = pendingChanges
        self.syncInProgress = syncInProgress
    }
}
