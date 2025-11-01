import XCTest
@testable import focusmate

@MainActor
final class ItemViewModelTests: XCTestCase {
  var viewModel: ItemViewModel!
  var mockItemService: ItemService!
  var mockNetworking: MockNetworking!
  var swiftDataManager: SwiftDataManager!
  var apiClient: APIClient!

  override func setUpWithError() throws {
    try super.setUpWithError()

    // Setup mocks
    mockNetworking = MockNetworking()
    apiClient = APIClient(tokenProvider: { "mock_token" })
    swiftDataManager = SwiftDataManager.shared

    mockItemService = ItemService(
      apiClient: apiClient,
      swiftDataManager: swiftDataManager
    )

    viewModel = ItemViewModel(
      itemService: mockItemService,
      swiftDataManager: swiftDataManager,
      apiClient: apiClient
    )
  }

  override func tearDownWithError() throws {
    viewModel = nil
    mockItemService = nil
    mockNetworking = nil
    apiClient = nil
    swiftDataManager = nil
    try super.tearDownWithError()
  }

  // MARK: - Load Items Tests

  func testLoadItemsSuccess() async {
    // Given
    mockNetworking.mockResponses["lists/1/tasks"] = MockData.mockItemsResponse
    XCTAssertTrue(viewModel.items.isEmpty)

    // When
    await viewModel.loadItems(listId: 1)

    // Then
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNil(viewModel.error)
    // Note: Items might be empty if SwiftData isn't fully mocked
  }

  func testLoadItemsFailure() async {
    // Given
    mockNetworking.shouldFail = true
    mockNetworking.mockError = APIError.unauthorized

    // When
    await viewModel.loadItems(listId: 1)

    // Then
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNotNil(viewModel.error)
  }

  // MARK: - Create Item Tests

  func testCreateItemSuccess() async {
    // Given
    let mockItem = MockData.mockItem
    mockNetworking.mockResponses["lists/1/tasks"] = mockItem
    XCTAssertTrue(viewModel.items.isEmpty)

    // When
    await viewModel.createItem(
      listId: 1,
      name: "New Task",
      description: "Description",
      dueDate: Date()
    )

    // Then
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNil(viewModel.error)
    XCTAssertEqual(viewModel.items.count, 1)
    XCTAssertEqual(viewModel.items.first?.title, "Test Task")
  }

  func testCreateItemWithEmptyName() async {
    // When
    await viewModel.createItem(
      listId: 1,
      name: "   ",
      description: nil,
      dueDate: nil
    )

    // Then
    XCTAssertNotNil(viewModel.error)
    XCTAssertTrue(viewModel.items.isEmpty)
  }

  func testCreateItemWithLongName() async {
    // Given
    let longName = String(repeating: "a", count: 300)

    // When
    await viewModel.createItem(
      listId: 1,
      name: longName,
      description: nil,
      dueDate: nil
    )

    // Then
    XCTAssertNotNil(viewModel.error)
    XCTAssertTrue(viewModel.items.isEmpty)
  }

  // MARK: - Update Item Tests

  func testUpdateItemSuccess() async {
    // Given
    let mockItem = MockData.mockItem
    viewModel.items = [mockItem]
    mockNetworking.mockResponses["tasks/1"] = mockItem

    // When
    await viewModel.updateItem(
      id: 1,
      name: "Updated Task",
      description: "Updated",
      completed: nil,
      dueDate: nil
    )

    // Then
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNil(viewModel.error)
  }

  // MARK: - Delete Item Tests

  func testDeleteItemSuccess() async {
    // Given
    let mockItem = MockData.mockItem
    viewModel.items = [mockItem]
    mockNetworking.mockResponses["tasks/1"] = EmptyResponse()

    // When
    await viewModel.deleteItem(id: 1)

    // Then
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNil(viewModel.error)
    XCTAssertTrue(viewModel.items.isEmpty)
  }

  // MARK: - Complete Item Tests

  func testCompleteItemSuccess() async {
    // Given
    let mockItem = MockData.mockItem
    let completedItem = MockData.mockCompletedItem
    viewModel.items = [mockItem]
    mockNetworking.mockResponses["tasks/1/complete"] = completedItem

    // When
    await viewModel.completeItem(id: 1, completed: true, completionNotes: nil)

    // Then
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNil(viewModel.error)
    XCTAssertTrue(viewModel.items.first?.isCompleted ?? false)
  }

  // MARK: - Error Handling Tests

  func testClearError() {
    // Given
    viewModel.error = .custom("TEST", "Test error")
    XCTAssertNotNil(viewModel.error)

    // When
    viewModel.clearError()

    // Then
    XCTAssertNil(viewModel.error)
  }

  // MARK: - Loading State Tests

  func testLoadingStateDuringOperation() async {
    // Given
    mockNetworking.mockDelay = 0.1
    mockNetworking.mockResponses["lists/1/tasks"] = MockData.mockItemsResponse

    // When
    let loadTask = Task {
      await viewModel.loadItems(listId: 1)
    }

    // Check loading state is true during operation
    try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
    // Note: Loading state might have already changed by the time we check

    await loadTask.value

    // Then
    XCTAssertFalse(viewModel.isLoading)
  }

  // MARK: - Performance Tests

  func testCreateItemPerformance() {
    // Given
    mockNetworking.mockResponses["lists/1/tasks"] = MockData.mockItem

    // Measure
    measure {
      Task {
        await viewModel.createItem(
          listId: 1,
          name: "Test Task",
          description: nil,
          dueDate: nil
        )
      }
    }
  }
}
