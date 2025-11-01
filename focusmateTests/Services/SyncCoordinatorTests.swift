import XCTest
import SwiftData
@testable import focusmate

@MainActor
final class SyncCoordinatorTests: XCTestCase {
  var syncCoordinator: SyncCoordinator!
  var mockItemService: MockItemService!
  var mockListService: MockListService!
  var swiftDataManager: SwiftDataManager!

  override func setUpWithError() throws {
    try super.setUpWithError()

    // Initialize SwiftDataManager with in-memory configuration for testing
    swiftDataManager = SwiftDataManager.shared

    // Create mock services
    mockItemService = MockItemService()
    mockListService = MockListService()

    // Initialize sync coordinator with mocks
    syncCoordinator = SyncCoordinator(
      itemService: mockItemService,
      listService: mockListService,
      swiftDataManager: swiftDataManager
    )
  }

  override func tearDownWithError() throws {
    syncCoordinator = nil
    mockItemService = nil
    mockListService = nil
    try super.tearDownWithError()
  }

  // MARK: - Full Sync Tests

  func testSyncAllSuccess() async throws {
    // Given
    mockListService.shouldSucceed = true
    mockItemService.shouldSucceed = true

    XCTAssertFalse(syncCoordinator.isSyncing)
    XCTAssertNil(syncCoordinator.lastSyncTime)

    // When
    try await syncCoordinator.syncAll()

    // Then
    XCTAssertFalse(syncCoordinator.isSyncing)
    XCTAssertNotNil(syncCoordinator.lastSyncTime)
    XCTAssertNil(syncCoordinator.syncError)
    XCTAssertTrue(mockListService.fetchListsCalled)
    XCTAssertTrue(mockItemService.syncItemsForListCalled)
  }

  func testSyncAllFailure() async {
    // Given
    mockListService.shouldSucceed = false
    mockListService.errorToThrow = MockError.networkError

    XCTAssertFalse(syncCoordinator.isSyncing)

    // When
    do {
      try await syncCoordinator.syncAll()
      XCTFail("Should have thrown error")
    } catch {
      // Then
      XCTAssertFalse(syncCoordinator.isSyncing)
      XCTAssertNotNil(syncCoordinator.syncError)
      XCTAssertTrue(mockListService.fetchListsCalled)
    }
  }

  func testSyncAllSetsIsSyncingFlag() async {
    // Given
    mockListService.shouldSucceed = true
    mockItemService.shouldSucceed = true

    // Create expectation to check isSyncing during operation
    var wasSyncingDuringOperation = false

    // When
    Task {
      // Check flag shortly after starting
      try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
      wasSyncingDuringOperation = syncCoordinator.isSyncing
    }

    try? await syncCoordinator.syncAll()

    // Then
    XCTAssertTrue(wasSyncingDuringOperation)
    XCTAssertFalse(syncCoordinator.isSyncing) // Should be false after completion
  }

  func testSyncAllClearsErrorOnStart() async {
    // Given
    mockListService.shouldSucceed = true
    mockItemService.shouldSucceed = true
    syncCoordinator.syncError = MockError.networkError

    // When
    try? await syncCoordinator.syncAll()

    // Then
    XCTAssertNil(syncCoordinator.syncError)
  }

  // MARK: - List Sync Tests

  func testSyncListSuccess() async throws {
    // Given
    let listId = 1
    mockItemService.shouldSucceed = true

    XCTAssertFalse(syncCoordinator.isSyncing)
    XCTAssertNil(syncCoordinator.lastSyncTime)

    // When
    try await syncCoordinator.syncList(id: listId)

    // Then
    XCTAssertFalse(syncCoordinator.isSyncing)
    XCTAssertNotNil(syncCoordinator.lastSyncTime)
    XCTAssertNil(syncCoordinator.syncError)
    XCTAssertTrue(mockItemService.syncItemsForListCalled)
    XCTAssertEqual(mockItemService.lastSyncedListId, listId)
  }

  func testSyncListFailure() async {
    // Given
    let listId = 1
    mockItemService.shouldSucceed = false
    mockItemService.errorToThrow = MockError.networkError

    XCTAssertFalse(syncCoordinator.isSyncing)

    // When
    do {
      try await syncCoordinator.syncList(id: listId)
      XCTFail("Should have thrown error")
    } catch {
      // Then
      XCTAssertFalse(syncCoordinator.isSyncing)
      XCTAssertNotNil(syncCoordinator.syncError)
      XCTAssertTrue(mockItemService.syncItemsForListCalled)
    }
  }

  func testSyncListSetsIsSyncingFlag() async {
    // Given
    let listId = 1
    mockItemService.shouldSucceed = true

    // When & Then
    var wasSyncingDuringOperation = false

    Task {
      try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
      wasSyncingDuringOperation = syncCoordinator.isSyncing
    }

    try? await syncCoordinator.syncList(id: listId)

    XCTAssertTrue(wasSyncingDuringOperation)
    XCTAssertFalse(syncCoordinator.isSyncing)
  }

  // MARK: - State Management Tests

  func testLastSyncTimeUpdatedOnSuccess() async throws {
    // Given
    mockListService.shouldSucceed = true
    mockItemService.shouldSucceed = true
    let beforeSync = Date()

    // When
    try await syncCoordinator.syncAll()

    // Then
    XCTAssertNotNil(syncCoordinator.lastSyncTime)
    if let lastSyncTime = syncCoordinator.lastSyncTime {
      XCTAssertGreaterThanOrEqual(lastSyncTime, beforeSync)
    }
  }

  func testLastSyncTimeNotUpdatedOnFailure() async {
    // Given
    mockListService.shouldSucceed = false
    mockListService.errorToThrow = MockError.networkError

    // When
    try? await syncCoordinator.syncAll()

    // Then
    XCTAssertNil(syncCoordinator.lastSyncTime)
  }

  func testSyncErrorSetOnFailure() async {
    // Given
    mockListService.shouldSucceed = false
    mockListService.errorToThrow = MockError.networkError

    // When
    try? await syncCoordinator.syncAll()

    // Then
    XCTAssertNotNil(syncCoordinator.syncError)
  }

  // MARK: - Published Property Tests

  func testIsSyncingPublished() async {
    // Given
    mockListService.shouldSucceed = true
    mockItemService.shouldSucceed = true

    var receivedValues: [Bool] = []
    let cancellable = syncCoordinator.$isSyncing.sink { value in
      receivedValues.append(value)
    }

    // When
    try? await syncCoordinator.syncAll()

    // Then
    XCTAssertTrue(receivedValues.contains(false)) // Initial value
    XCTAssertTrue(receivedValues.contains(true))  // During sync

    cancellable.cancel()
  }
}

// MARK: - Mock Services

class MockItemService: ItemService {
  var shouldSucceed = true
  var errorToThrow: Error = MockError.networkError
  var syncItemsForListCalled = false
  var lastSyncedListId: Int?

  init() {
    let mockAPIClient = MockAPIClient()
    super.init(apiClient: mockAPIClient, swiftDataManager: SwiftDataManager.shared)
  }

  override func syncItemsForList(listId: Int) async throws {
    syncItemsForListCalled = true
    lastSyncedListId = listId

    if !shouldSucceed {
      throw errorToThrow
    }

    // Simulate successful sync by not throwing
  }
}

class MockListService: ListService {
  var shouldSucceed = true
  var errorToThrow: Error = MockError.networkError
  var fetchListsCalled = false

  init() {
    let mockAPIClient = MockAPIClient()
    super.init(apiClient: mockAPIClient)
  }

  override func fetchLists() async throws -> [ListDTO] {
    fetchListsCalled = true

    if !shouldSucceed {
      throw errorToThrow
    }

    // Return mock data
    return [
      ListDTO(
        id: 1,
        name: "Test List 1",
        title: "Test List 1",
        description: "Test description 1",
        user_id: 1,
        created_at: "2024-01-01T00:00:00Z",
        updated_at: "2024-01-01T00:00:00Z"
      ),
      ListDTO(
        id: 2,
        name: "Test List 2",
        title: "Test List 2",
        description: "Test description 2",
        user_id: 1,
        created_at: "2024-01-01T00:00:00Z",
        updated_at: "2024-01-01T00:00:00Z"
      ),
    ]
  }
}

enum MockError: Error {
  case networkError
  case unknownError
}
