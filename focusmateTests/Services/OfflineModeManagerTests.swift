import XCTest
@testable import focusmate

@MainActor
final class OfflineModeManagerTests: XCTestCase {
  var manager: OfflineModeManager!

  override func setUpWithError() throws {
    try super.setUpWithError()
    manager = OfflineModeManager.shared
  }

  override func tearDownWithError() throws {
    // Clear pending operations after each test
    manager.pendingOperations.removeAll()
    manager = nil
    try super.tearDownWithError()
  }

  // MARK: - Pending Operations Tests

  func testAddPendingOperation() {
    // Given
    let operation = PendingOperation(
      type: .createItem,
      data: ["title": "Test Task", "listId": "1"]
    )
    let initialCount = manager.pendingOperations.count

    // When
    manager.addPendingOperation(operation)

    // Then
    XCTAssertEqual(manager.pendingOperations.count, initialCount + 1)
    XCTAssertTrue(manager.pendingOperations.contains { $0.id == operation.id })
  }

  func testRemovePendingOperation() {
    // Given
    let operation = PendingOperation(
      type: .updateItem,
      data: ["title": "Updated Task"]
    )
    manager.addPendingOperation(operation)
    XCTAssertTrue(manager.pendingOperations.contains { $0.id == operation.id })

    // When
    manager.removePendingOperation(operation)

    // Then
    XCTAssertFalse(manager.pendingOperations.contains { $0.id == operation.id })
  }

  func testMultiplePendingOperations() {
    // Given
    let operation1 = PendingOperation(type: .createItem, data: ["title": "Task 1"])
    let operation2 = PendingOperation(type: .updateItem, data: ["title": "Task 2"])
    let operation3 = PendingOperation(type: .deleteItem, data: ["id": "123"])

    // When
    manager.addPendingOperation(operation1)
    manager.addPendingOperation(operation2)
    manager.addPendingOperation(operation3)

    // Then
    XCTAssertEqual(manager.pendingOperations.count, 3)
    XCTAssertTrue(manager.pendingOperations.contains { $0.id == operation1.id })
    XCTAssertTrue(manager.pendingOperations.contains { $0.id == operation2.id })
    XCTAssertTrue(manager.pendingOperations.contains { $0.id == operation3.id })
  }

  // MARK: - Connection Helper Tests

  func testRequiresOnline() {
    // When online
    if manager.isOnline {
      XCTAssertFalse(manager.requiresOnline())
    } else {
      XCTAssertTrue(manager.requiresOnline())
    }
  }

  func testCanPerformOperation() {
    // Should match isOnline status
    XCTAssertEqual(manager.canPerformOperation(), manager.isOnline)
  }

  // MARK: - PendingOperation Model Tests

  func testPendingOperationCreation() {
    // Given
    let data = ["title": "Test", "description": "Description"]
    let operation = PendingOperation(type: .createItem, data: data)

    // Then
    XCTAssertNotNil(operation.id)
    XCTAssertEqual(operation.type, .createItem)
    XCTAssertEqual(operation.data, data)
    XCTAssertNotNil(operation.timestamp)
  }

  func testPendingOperationTypes() {
    // Test all operation types
    let createOp = PendingOperation(type: .createItem, data: [:])
    let updateOp = PendingOperation(type: .updateItem, data: [:])
    let deleteOp = PendingOperation(type: .deleteItem, data: [:])
    let completeOp = PendingOperation(type: .completeItem, data: [:])

    XCTAssertEqual(createOp.type, .createItem)
    XCTAssertEqual(updateOp.type, .updateItem)
    XCTAssertEqual(deleteOp.type, .deleteItem)
    XCTAssertEqual(completeOp.type, .completeItem)
  }

  // MARK: - ConnectionQuality Tests

  func testConnectionQualityValues() {
    XCTAssertEqual(ConnectionQuality.excellent.rawValue, "Excellent")
    XCTAssertEqual(ConnectionQuality.good.rawValue, "Good")
    XCTAssertEqual(ConnectionQuality.fair.rawValue, "Fair")
    XCTAssertEqual(ConnectionQuality.poor.rawValue, "Poor")
    XCTAssertEqual(ConnectionQuality.offline.rawValue, "Offline")
  }

  func testConnectionQualityIcons() {
    XCTAssertEqual(ConnectionQuality.excellent.icon, "wifi")
    XCTAssertEqual(ConnectionQuality.good.icon, "wifi")
    XCTAssertEqual(ConnectionQuality.fair.icon, "wifi")
    XCTAssertEqual(ConnectionQuality.poor.icon, "wifi.slash")
    XCTAssertEqual(ConnectionQuality.offline.icon, "wifi.slash")
  }

  func testConnectionQualityColors() {
    XCTAssertEqual(ConnectionQuality.excellent.color, "green")
    XCTAssertEqual(ConnectionQuality.good.color, "green")
    XCTAssertEqual(ConnectionQuality.fair.color, "yellow")
    XCTAssertEqual(ConnectionQuality.poor.color, "red")
    XCTAssertEqual(ConnectionQuality.offline.color, "red")
  }

  // MARK: - OperationType Codable Tests

  func testOperationTypeCoding() throws {
    // Given
    let types: [OperationType] = [.createItem, .updateItem, .deleteItem, .completeItem]

    for type in types {
      // When
      let encoded = try JSONEncoder().encode(type)
      let decoded = try JSONDecoder().decode(OperationType.self, from: encoded)

      // Then
      XCTAssertEqual(decoded, type)
    }
  }
}
