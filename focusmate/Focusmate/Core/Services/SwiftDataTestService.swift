import Foundation
import SwiftData

@MainActor
final class SwiftDataTestService {
  private let swiftDataManager: SwiftDataManager

  init(swiftDataManager: SwiftDataManager) {
    self.swiftDataManager = swiftDataManager
  }

  func testSwiftDataIntegration() async {
    #if DEBUG
    print("🧪 SwiftDataTestService: Testing SwiftData integration...")
    #endif

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
      #if DEBUG
      print("✅ SwiftDataTestService: Test data created successfully")
      #endif

      // Test fetching data
      let userFetchDescriptor = FetchDescriptor<User>(
        predicate: #Predicate { $0.id == 999 }
      )
      let users = try context.fetch(userFetchDescriptor)
      #if DEBUG
      print("✅ SwiftDataTestService: Found \(users.count) test users")
      #endif

      let listFetchDescriptor = FetchDescriptor<List>(
        predicate: #Predicate { $0.id == 999 }
      )
      let lists = try context.fetch(listFetchDescriptor)
      #if DEBUG
      print("✅ SwiftDataTestService: Found \(lists.count) test lists")
      #endif

      let itemFetchDescriptor = FetchDescriptor<TaskItem>(
        predicate: #Predicate { $0.id == 999 }
      )
      let items = try context.fetch(itemFetchDescriptor)
      #if DEBUG
      print("✅ SwiftDataTestService: Found \(items.count) test items")
      #endif

      // Test relationships
      if let firstList = lists.first {
        #if DEBUG
        print("✅ SwiftDataTestService: List owner: \(firstList.owner?.email ?? "nil")")
        #endif
        #if DEBUG
        print("✅ SwiftDataTestService: List items count: \(firstList.items.count)")
        #endif
      }

      if let firstItem = items.first {
        #if DEBUG
        print("✅ SwiftDataTestService: Item creator: \(firstItem.creator?.email ?? "nil")")
        #endif
        #if DEBUG
        print("✅ SwiftDataTestService: Item list: \(firstItem.list?.name ?? "nil")")
        #endif
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
      #if DEBUG
      print("✅ SwiftDataTestService: Test data cleaned up successfully")
      #endif

    } catch {
      #if DEBUG
      print("❌ SwiftDataTestService: Test failed: \(error)")
      #endif
    }
  }

  func testDeltaSyncParameters() {
    #if DEBUG
    print("🧪 SwiftDataTestService: Testing delta sync parameters...")
    #endif

    // Test getting sync parameters for different entity types
    let userParams = self.swiftDataManager.getDeltaSyncParameters(for: "users")
    let listParams = self.swiftDataManager.getDeltaSyncParameters(for: "lists")
    let itemParams = self.swiftDataManager.getDeltaSyncParameters(for: "items")

    #if DEBUG
    print("✅ SwiftDataTestService: User sync params: \(userParams)")
    #endif
    #if DEBUG
    print("✅ SwiftDataTestService: List sync params: \(listParams)")
    #endif
    #if DEBUG
    print("✅ SwiftDataTestService: Item sync params: \(itemParams)")
    #endif

    // Test updating sync timestamps
    let now = Date()
    self.swiftDataManager.updateLastSyncTimestamp(for: "users", timestamp: now, since: "2024-01-01T00:00:00Z")
    self.swiftDataManager.updateLastSyncTimestamp(for: "lists", timestamp: now, since: "2024-01-01T00:00:00Z")
    self.swiftDataManager.updateLastSyncTimestamp(for: "items", timestamp: now, since: "2024-01-01T00:00:00Z")

    #if DEBUG
    print("✅ SwiftDataTestService: Sync timestamps updated")
    #endif

    // Test getting updated parameters
    let updatedUserParams = self.swiftDataManager.getDeltaSyncParameters(for: "users")
    #if DEBUG
    print("✅ SwiftDataTestService: Updated user sync params: \(updatedUserParams)")
    #endif
  }
}
