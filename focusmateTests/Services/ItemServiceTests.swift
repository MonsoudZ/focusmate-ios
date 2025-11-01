import XCTest
@testable import focusmate

@MainActor
final class ItemServiceTests: XCTestCase {
  var itemService: ItemService!
  var mockNetworking: MockNetworking!
  var swiftDataManager: SwiftDataManager!

  override func setUpWithError() throws {
    try super.setUpWithError()

    // Create mock networking
    mockNetworking = MockNetworking()

    // Create API client with mock networking
    let apiClient = APIClient(tokenProvider: { "mock_token" })

    // Use in-memory SwiftData for testing
    swiftDataManager = SwiftDataManager.shared

    // Create ItemService with dependencies
    itemService = ItemService(
      apiClient: apiClient,
      swiftDataManager: swiftDataManager
    )
  }

  override func tearDownWithError() throws {
    itemService = nil
    mockNetworking = nil
    swiftDataManager = nil
    try super.tearDownWithError()
  }

  // MARK: - Fetch Items Tests

  func testFetchItemsSuccess() async throws {
    // Given
    let mockResponse = MockData.mockItemsResponse
    mockNetworking.mockResponses["lists/1/tasks"] = mockResponse

    // When
    let items = try await itemService.fetchItems(listId: 1)

    // Then
    XCTAssertEqual(items.count, 4)
    XCTAssertEqual(items.first?.id, 1)
    XCTAssertEqual(items.first?.title, "Test Task")
  }

  func testFetchItemsFailure() async {
    // Given
    mockNetworking.shouldFail = true
    mockNetworking.mockError = APIError.unauthorized

    // When/Then
    do {
      _ = try await itemService.fetchItems(listId: 1)
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertTrue(error is APIError)
    }
  }

  // MARK: - Create Item Tests

  func testCreateItemSuccess() async throws {
    // Given
    let mockItem = MockData.mockItem
    mockNetworking.mockResponses["lists/1/tasks"] = mockItem

    // When
    let item = try await itemService.createItem(
      listId: 1,
      name: "New Task",
      description: "Task description",
      dueDate: Date()
    )

    // Then
    XCTAssertEqual(item.id, 1)
    XCTAssertEqual(mockNetworking.requestCallCount, 1)
  }

  func testCreateItemWithRecurrence() async throws {
    // Given
    let mockItem = MockData.mockRecurringItem
    mockNetworking.mockResponses["lists/1/tasks"] = mockItem

    // When
    let item = try await itemService.createItem(
      listId: 1,
      name: "Weekly Task",
      description: nil,
      dueDate: Date(),
      isRecurring: true,
      recurrencePattern: "weekly",
      recurrenceInterval: 1,
      recurrenceDays: [1, 3, 5]
    )

    // Then
    XCTAssertTrue(item.is_recurring)
    XCTAssertEqual(item.recurrence_pattern, "weekly")
    XCTAssertEqual(item.recurrence_days, [1, 3, 5])
  }

  func testCreateItemWithLocation() async throws {
    // Given
    let mockItem = MockData.mockLocationItem
    mockNetworking.mockResponses["lists/1/tasks"] = mockItem

    // When
    let item = try await itemService.createItem(
      listId: 1,
      name: "Gym Task",
      description: nil,
      dueDate: nil,
      locationBased: true,
      locationName: "Local Gym",
      locationLatitude: 37.7749,
      locationLongitude: -122.4194,
      locationRadiusMeters: 200,
      notifyOnArrival: true
    )

    // Then
    XCTAssertTrue(item.location_based)
    XCTAssertEqual(item.location_name, "Local Gym")
    XCTAssertEqual(item.location_latitude, 37.7749)
    XCTAssertEqual(item.location_radius_meters, 200)
  }

  // MARK: - Update Item Tests

  func testUpdateItemSuccess() async throws {
    // Given
    let updatedItem = MockData.mockItem
    mockNetworking.mockResponses["tasks/1"] = updatedItem

    // When
    let item = try await itemService.updateItem(
      id: 1,
      name: "Updated Task",
      description: "Updated description",
      completed: nil,
      dueDate: Date()
    )

    // Then
    XCTAssertEqual(item.id, 1)
    XCTAssertEqual(mockNetworking.requestCallCount, 1)
  }

  func testUpdateItemCompletion() async throws {
    // Given
    let completedItem = MockData.mockCompletedItem
    mockNetworking.mockResponses["tasks/1"] = completedItem

    // When
    let item = try await itemService.updateItem(
      id: 1,
      name: nil,
      description: nil,
      completed: true,
      dueDate: nil
    )

    // Then
    XCTAssertTrue(item.isCompleted)
    XCTAssertNotNil(item.completed_at)
  }

  // MARK: - Delete Item Tests

  func testDeleteItemSuccess() async throws {
    // Given
    mockNetworking.mockResponses["tasks/1"] = EmptyResponse()

    // When/Then
    try await itemService.deleteItem(id: 1)
    XCTAssertEqual(mockNetworking.requestCallCount, 1)
  }

  // MARK: - Complete Item Tests

  func testCompleteItemSuccess() async throws {
    // Given
    let completedItem = MockData.mockCompletedItem
    mockNetworking.mockResponses["tasks/1/complete"] = completedItem

    // When
    let item = try await itemService.completeItem(
      id: 1,
      completed: true,
      completionNotes: "Done!"
    )

    // Then
    XCTAssertTrue(item.isCompleted)
    XCTAssertNotNil(item.completed_at)
  }

  func testUncompleteItemSuccess() async throws {
    // Given
    let uncompletedItem = MockData.mockItem
    mockNetworking.mockResponses["tasks/1/complete"] = uncompletedItem

    // When
    let item = try await itemService.completeItem(
      id: 1,
      completed: false,
      completionNotes: nil
    )

    // Then
    XCTAssertFalse(item.isCompleted)
    XCTAssertNil(item.completed_at)
  }

  // MARK: - Performance Tests

  func testFetchItemsPerformance() {
    // Given
    mockNetworking.mockResponses["lists/1/tasks"] = MockData.mockItemsResponse

    // Measure
    measure {
      Task {
        _ = try? await itemService.fetchItems(listId: 1)
      }
    }
  }
}
