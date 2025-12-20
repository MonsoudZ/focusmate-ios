import Foundation
import SwiftData

@MainActor
final class SwiftDataTestService {
  private let swiftDataManager: SwiftDataManager

  init(swiftDataManager: SwiftDataManager) {
    self.swiftDataManager = swiftDataManager
  }

  func testSwiftDataIntegration() async {
    Logger.debug("SwiftDataTestService: Testing SwiftData integration...", category: .database)

    let context = self.swiftDataManager.context

    // Test creating a user
    let testUser = User(
      id: 999,
      email: "test@example.com",
      name: "Test User",
      role: "client",
      timezone: "UTC",
      createdAt: Date()
    )

    context.insert(testUser)

    // Test creating a list
    let testList = List(
      id: 999,
      name: "Test List",
      description: "Test Description",
      role: "owner",
      tasksCount: 0,
      overdueTasksCount: 0,
      createdAt: Date(),
      updatedAt: Date()
    )

    testList.owner = testUser
    context.insert(testList)

    // Test creating an item
    let testItem = TaskItem(
      id: 999,
      listId: 999,
      title: "Test Item",
      description: "Test Item Description",
      dueAt: Date().addingTimeInterval(3600), // 1 hour from now
      completedAt: nil,
      priority: 2,
      canBeSnoozed: true,
      notificationIntervalMinutes: 10,
      requiresExplanationIfMissed: false,
      overdue: false,
      minutesOverdue: 0,
      requiresExplanation: false,
      isRecurring: false,
      recurrencePattern: nil,
      recurrenceInterval: 1,
      recurrenceDays: nil,
      locationBased: false,
      locationName: nil,
      locationLatitude: nil,
      locationLongitude: nil,
      locationRadiusMeters: 100,
      notifyOnArrival: true,
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
      updatedAt: Date()
    )

    testItem.creator = testUser
    testItem.list = testList
    context.insert(testItem)

    // Save the context
    do {
      try context.save()
      Logger.info("SwiftDataTestService: Test data created successfully", category: .database)

      // Test fetching data
      let userFetchDescriptor = FetchDescriptor<User>(
        predicate: #Predicate { $0.id == 999 }
      )
      let users = try context.fetch(userFetchDescriptor)
      Logger.info("SwiftDataTestService: Found \(users.count) test users", category: .database)

      let listFetchDescriptor = FetchDescriptor<List>(
        predicate: #Predicate { $0.id == 999 }
      )
      let lists = try context.fetch(listFetchDescriptor)
      Logger.info("SwiftDataTestService: Found \(lists.count) test lists", category: .database)

      let itemFetchDescriptor = FetchDescriptor<TaskItem>(
        predicate: #Predicate { $0.id == 999 }
      )
      let items = try context.fetch(itemFetchDescriptor)
      Logger.info("SwiftDataTestService: Found \(items.count) test items", category: .database)

      // Test relationships
      if let firstList = lists.first {
        Logger.info("SwiftDataTestService: List owner: \(firstList.owner?.email ?? "nil")", category: .database)
        Logger.info("SwiftDataTestService: List items count: \(firstList.items.count)", category: .database)
      }

      if let firstItem = items.first {
        Logger.info("SwiftDataTestService: Item creator: \(firstItem.creator?.email ?? "nil")", category: .database)
        Logger.info("SwiftDataTestService: Item list: \(firstItem.list?.name ?? "nil")", category: .database)
      }

      // Clean up test data
      for user in users {
        context.delete(user)
      }
      for list in lists {
        context.delete(list)
      }
      for item in items {
        context.delete(item)
      }

      try context.save()
      Logger.info("SwiftDataTestService: Test data cleaned up successfully", category: .database)

    } catch {
      Logger.error("SwiftDataTestService: Test failed: \(error)", category: .database)
    }
  }

  func testDeltaSyncParameters() {
    Logger.debug("SwiftDataTestService: Testing delta sync parameters...", category: .database)

    // Test getting sync parameters for different entity types
    let userParams = self.swiftDataManager.getDeltaSyncParameters(for: "users")
    let listParams = self.swiftDataManager.getDeltaSyncParameters(for: "lists")
    let itemParams = self.swiftDataManager.getDeltaSyncParameters(for: "items")

    Logger.info("SwiftDataTestService: User sync params: \(userParams)", category: .database)
    Logger.info("SwiftDataTestService: List sync params: \(listParams)", category: .database)
    Logger.info("SwiftDataTestService: Item sync params: \(itemParams)", category: .database)

    // Test updating sync timestamps
    let now = Date()
    self.swiftDataManager.updateLastSyncTimestamp(for: "users", timestamp: now, since: "2024-01-01T00:00:00Z")
    self.swiftDataManager.updateLastSyncTimestamp(for: "lists", timestamp: now, since: "2024-01-01T00:00:00Z")
    self.swiftDataManager.updateLastSyncTimestamp(for: "items", timestamp: now, since: "2024-01-01T00:00:00Z")

    Logger.info("SwiftDataTestService: Sync timestamps updated", category: .database)

    // Test getting updated parameters
    let updatedUserParams = self.swiftDataManager.getDeltaSyncParameters(for: "users")
    Logger.info("SwiftDataTestService: Updated user sync params: \(updatedUserParams)", category: .database)
  }
}
