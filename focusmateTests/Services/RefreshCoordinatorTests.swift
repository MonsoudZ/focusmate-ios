import XCTest
import Combine
@testable import focusmate

@MainActor
final class RefreshCoordinatorTests: XCTestCase {
  var coordinator: RefreshCoordinator!
  var cancellables: Set<AnyCancellable>!

  override func setUpWithError() throws {
    try super.setUpWithError()
    coordinator = RefreshCoordinator.shared
    cancellables = Set<AnyCancellable>()
  }

  override func tearDownWithError() throws {
    cancellables = nil
    coordinator = nil
    try super.tearDownWithError()
  }

  // MARK: - Refresh Event Tests

  func testTriggerListsRefresh() async throws {
    // Given
    let expectation = XCTestExpectation(description: "Lists refresh event received")
    var receivedEvent: RefreshEvent?

    coordinator.refreshPublisher
      .sink { event in
        receivedEvent = event
        expectation.fulfill()
      }
      .store(in: &cancellables)

    // When
    coordinator.triggerRefresh(.lists)

    // Then
    await fulfillment(of: [expectation], timeout: 1.0)
    XCTAssertEqual(receivedEvent, .lists)
  }

  func testTriggerItemsRefresh() async throws {
    // Given
    let expectation = XCTestExpectation(description: "Items refresh event received")
    let testListId = 42
    var receivedEvent: RefreshEvent?

    coordinator.refreshPublisher
      .sink { event in
        receivedEvent = event
        expectation.fulfill()
      }
      .store(in: &cancellables)

    // When
    coordinator.triggerRefresh(.items(listId: testListId))

    // Then
    await fulfillment(of: [expectation], timeout: 1.0)
    XCTAssertEqual(receivedEvent, .items(listId: testListId))
  }

  func testTriggerListRefresh() async throws {
    // Given
    let expectation = XCTestExpectation(description: "List refresh event received")
    let testListId = 123
    var receivedEvent: RefreshEvent?

    coordinator.refreshPublisher
      .sink { event in
        receivedEvent = event
        expectation.fulfill()
      }
      .store(in: &cancellables)

    // When
    coordinator.triggerRefresh(.list(id: testListId))

    // Then
    await fulfillment(of: [expectation], timeout: 1.0)
    XCTAssertEqual(receivedEvent, .list(id: testListId))
  }

  func testTriggerItemRefresh() async throws {
    // Given
    let expectation = XCTestExpectation(description: "Item refresh event received")
    let testItemId = 789
    var receivedEvent: RefreshEvent?

    coordinator.refreshPublisher
      .sink { event in
        receivedEvent = event
        expectation.fulfill()
      }
      .store(in: &cancellables)

    // When
    coordinator.triggerRefresh(.item(id: testItemId))

    // Then
    await fulfillment(of: [expectation], timeout: 1.0)
    XCTAssertEqual(receivedEvent, .item(id: testItemId))
  }

  // MARK: - Multiple Subscribers Test

  func testMultipleSubscribers() async throws {
    // Given
    let expectation1 = XCTestExpectation(description: "Subscriber 1 received event")
    let expectation2 = XCTestExpectation(description: "Subscriber 2 received event")
    var receivedEvent1: RefreshEvent?
    var receivedEvent2: RefreshEvent?

    coordinator.refreshPublisher
      .sink { event in
        receivedEvent1 = event
        expectation1.fulfill()
      }
      .store(in: &cancellables)

    coordinator.refreshPublisher
      .sink { event in
        receivedEvent2 = event
        expectation2.fulfill()
      }
      .store(in: &cancellables)

    // When
    coordinator.triggerRefresh(.lists)

    // Then
    await fulfillment(of: [expectation1, expectation2], timeout: 1.0)
    XCTAssertEqual(receivedEvent1, .lists)
    XCTAssertEqual(receivedEvent2, .lists)
  }

  // MARK: - RefreshEvent Equatable Tests

  func testRefreshEventEquality() {
    XCTAssertEqual(RefreshEvent.lists, RefreshEvent.lists)
    XCTAssertEqual(RefreshEvent.items(listId: 1), RefreshEvent.items(listId: 1))
    XCTAssertEqual(RefreshEvent.list(id: 2), RefreshEvent.list(id: 2))
    XCTAssertEqual(RefreshEvent.item(id: 3), RefreshEvent.item(id: 3))

    XCTAssertNotEqual(RefreshEvent.lists, RefreshEvent.list(id: 1))
    XCTAssertNotEqual(RefreshEvent.items(listId: 1), RefreshEvent.items(listId: 2))
  }

  // MARK: - Description Tests

  func testRefreshEventDescription() {
    XCTAssertEqual(RefreshEvent.lists.description, "lists")
    XCTAssertEqual(RefreshEvent.items(listId: 5).description, "items for list 5")
    XCTAssertEqual(RefreshEvent.list(id: 10).description, "list 10")
    XCTAssertEqual(RefreshEvent.item(id: 20).description, "item 20")
  }
}
