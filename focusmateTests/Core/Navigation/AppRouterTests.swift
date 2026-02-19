@testable import focusmate
import XCTest

@MainActor
final class AppRouterTests: XCTestCase {
  private var router: AppRouter!

  override func setUp() async throws {
    try await super.setUp()
    self.router = AppRouter.shared
    // Reset router state for clean test
    self.router.selectedTab = .today
    self.router.todayPath = []
    self.router.listsPath = []
    self.router.settingsPath = []
    self.router.activeSheet = nil
  }

  // MARK: - Initial State Tests

  func testInitialState() {
    XCTAssertEqual(self.router.selectedTab, .today)
    XCTAssertTrue(self.router.todayPath.isEmpty)
    XCTAssertTrue(self.router.listsPath.isEmpty)
    XCTAssertTrue(self.router.settingsPath.isEmpty)
    XCTAssertNil(self.router.activeSheet)
  }

  // MARK: - Tab Navigation Tests

  func testSwitchTab() {
    self.router.switchTab(to: .lists)
    XCTAssertEqual(self.router.selectedTab, .lists)

    self.router.switchTab(to: .settings)
    XCTAssertEqual(self.router.selectedTab, .settings)

    self.router.switchTab(to: .today)
    XCTAssertEqual(self.router.selectedTab, .today)
  }

  // MARK: - Push Navigation Tests

  func testPushToCurrentTab() {
    self.router.selectedTab = .lists
    let list = TestFactories.makeSampleList(id: 1, name: "Test List")

    self.router.push(.listDetail(list))

    XCTAssertEqual(self.router.listsPath.count, 1)
    XCTAssertTrue(self.router.todayPath.isEmpty)
    XCTAssertTrue(self.router.settingsPath.isEmpty)
  }

  func testPushToSpecificTab() {
    self.router.selectedTab = .today
    let list = TestFactories.makeSampleList(id: 1, name: "Test List")

    self.router.push(.listDetail(list), in: .lists)

    XCTAssertEqual(self.router.listsPath.count, 1)
    XCTAssertEqual(self.router.selectedTab, .lists)
  }

  func testPushMultipleRoutes() {
    self.router.selectedTab = .lists
    let list1 = TestFactories.makeSampleList(id: 1, name: "List 1")
    let list2 = TestFactories.makeSampleList(id: 2, name: "List 2")

    self.router.push(.listDetail(list1))
    self.router.push(.listDetail(list2))

    XCTAssertEqual(self.router.listsPath.count, 2)
  }

  // MARK: - Pop Navigation Tests

  func testPopFromCurrentTab() {
    self.router.selectedTab = .lists
    let list = TestFactories.makeSampleList(id: 1, name: "Test List")
    self.router.push(.listDetail(list))

    XCTAssertEqual(self.router.listsPath.count, 1)

    self.router.pop()

    XCTAssertTrue(self.router.listsPath.isEmpty)
  }

  func testPopFromSpecificTab() {
    let list = TestFactories.makeSampleList(id: 1, name: "Test List")
    self.router.push(.listDetail(list), in: .lists)
    self.router.selectedTab = .today

    self.router.pop(in: .lists)

    XCTAssertTrue(self.router.listsPath.isEmpty)
  }

  func testPopFromEmptyPathDoesNothing() {
    self.router.selectedTab = .today
    XCTAssertTrue(self.router.todayPath.isEmpty)

    self.router.pop()

    XCTAssertTrue(self.router.todayPath.isEmpty)
  }

  // MARK: - Pop to Root Tests

  func testPopToRoot() {
    self.router.selectedTab = .lists
    let list1 = TestFactories.makeSampleList(id: 1, name: "List 1")
    let list2 = TestFactories.makeSampleList(id: 2, name: "List 2")
    self.router.push(.listDetail(list1))
    self.router.push(.listDetail(list2))

    XCTAssertEqual(self.router.listsPath.count, 2)

    self.router.popToRoot()

    XCTAssertTrue(self.router.listsPath.isEmpty)
  }

  func testPopToRootInSpecificTab() {
    let list = TestFactories.makeSampleList(id: 1, name: "Test List")
    self.router.push(.listDetail(list), in: .lists)
    self.router.selectedTab = .today

    self.router.popToRoot(in: .lists)

    XCTAssertTrue(self.router.listsPath.isEmpty)
  }

  // MARK: - Sheet Presentation Tests

  func testPresentSheet() {
    self.router.present(.createList)

    XCTAssertNotNil(self.router.activeSheet)
    if case .createList = self.router.activeSheet {
      // Success
    } else {
      XCTFail("Expected createList sheet")
    }
  }

  func testDismissSheet() {
    self.router.present(.createList)
    XCTAssertNotNil(self.router.activeSheet)

    self.router.dismissSheet()

    XCTAssertNil(self.router.activeSheet)
  }

  func testDismissSheetClearsCallbacks() {
    var callbackCalled = false
    self.router.sheetCallbacks.onListCreated = {
      callbackCalled = true
    }
    self.router.present(.createList)

    self.router.dismissSheet()

    XCTAssertNil(self.router.sheetCallbacks.onListCreated)
    XCTAssertFalse(callbackCalled)
  }

  func testPresentDifferentSheetTypes() {
    let list = TestFactories.makeSampleList(id: 1, name: "Test")
    let task = TestFactories.makeSampleTask(id: 1, title: "Task")

    self.router.present(.createList)
    if case .createList = self.router.activeSheet {} else { XCTFail("Expected createList") }

    self.router.present(.editList(list))
    if case let .editList(l) = router.activeSheet {
      XCTAssertEqual(l.id, list.id)
    } else { XCTFail("Expected editList") }

    self.router.present(.taskDetail(task, listName: "List"))
    if case let .taskDetail(t, name) = router.activeSheet {
      XCTAssertEqual(t.id, task.id)
      XCTAssertEqual(name, "List")
    } else { XCTFail("Expected taskDetail") }

    self.router.present(.acceptInvite("ABC123"))
    if case let .acceptInvite(code) = router.activeSheet {
      XCTAssertEqual(code, "ABC123")
    } else { XCTFail("Expected acceptInvite") }
  }

  // MARK: - Convenience Method Tests

  func testNavigateToList() {
    self.router.selectedTab = .today
    let list = TestFactories.makeSampleList(id: 1, name: "Test List")

    self.router.navigateToList(list)

    XCTAssertEqual(self.router.selectedTab, .lists)
    XCTAssertEqual(self.router.listsPath.count, 1)
    if case let .listDetail(l) = router.listsPath.first {
      XCTAssertEqual(l.id, list.id)
    } else {
      XCTFail("Expected listDetail route")
    }
  }

  func testPresentInvite() {
    self.router.presentInvite(code: "INVITE123")

    if case let .acceptInvite(code) = router.activeSheet {
      XCTAssertEqual(code, "INVITE123")
    } else {
      XCTFail("Expected acceptInvite sheet")
    }
  }

  // MARK: - Deep Link Tests

  func testHandleDeepLinkWhenReady() {
    self.router.markReady()

    self.router.handleDeepLink(.openToday)

    XCTAssertEqual(self.router.selectedTab, .today)
  }

  func testHandleDeepLinkOpenInvite() {
    self.router.markReady()

    self.router.handleDeepLink(.openInvite(code: "TEST123"))

    if case let .acceptInvite(code) = router.activeSheet {
      XCTAssertEqual(code, "TEST123")
    } else {
      XCTFail("Expected acceptInvite sheet")
    }
  }

  func testDeepLinkBufferedBeforeReady() {
    // Don't call markReady()
    self.router.handleDeepLink(.openInvite(code: "BUFFERED"))

    // Sheet should not be presented yet
    XCTAssertNil(self.router.activeSheet)

    // Now mark ready
    self.router.markReady()

    // Buffered deep link should be executed
    if case let .acceptInvite(code) = router.activeSheet {
      XCTAssertEqual(code, "BUFFERED")
    } else {
      XCTFail("Expected buffered deep link to be executed")
    }
  }

  // MARK: - Sheet Callbacks Tests

  func testSheetCallbacksInitiallyNil() {
    XCTAssertNil(self.router.sheetCallbacks.onTaskCreated)
    XCTAssertNil(self.router.sheetCallbacks.onTaskCompleted)
    XCTAssertNil(self.router.sheetCallbacks.onTaskDeleted)
    XCTAssertNil(self.router.sheetCallbacks.onTaskUpdated)
    XCTAssertNil(self.router.sheetCallbacks.onSubtaskCreated)
    XCTAssertNil(self.router.sheetCallbacks.onSubtaskUpdated)
    XCTAssertNil(self.router.sheetCallbacks.onListCreated)
    XCTAssertNil(self.router.sheetCallbacks.onListUpdated)
    XCTAssertNil(self.router.sheetCallbacks.onListJoined)
  }

  func testSheetCallbacksCanBeSet() async {
    var taskCreatedCalled = false

    self.router.sheetCallbacks.onTaskCreated = {
      taskCreatedCalled = true
    }

    await self.router.sheetCallbacks.onTaskCreated?()

    XCTAssertTrue(taskCreatedCalled)
  }
}
