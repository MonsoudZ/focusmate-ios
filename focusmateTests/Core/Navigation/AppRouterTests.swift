import XCTest
@testable import focusmate

@MainActor
final class AppRouterTests: XCTestCase {

    private var router: AppRouter!

    override func setUp() async throws {
        try await super.setUp()
        router = AppRouter.shared
        // Reset router state for clean test
        router.selectedTab = .today
        router.todayPath = []
        router.listsPath = []
        router.settingsPath = []
        router.activeSheet = nil
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertEqual(router.selectedTab, .today)
        XCTAssertTrue(router.todayPath.isEmpty)
        XCTAssertTrue(router.listsPath.isEmpty)
        XCTAssertTrue(router.settingsPath.isEmpty)
        XCTAssertNil(router.activeSheet)
    }

    // MARK: - Tab Navigation Tests

    func testSwitchTab() {
        router.switchTab(to: .lists)
        XCTAssertEqual(router.selectedTab, .lists)

        router.switchTab(to: .settings)
        XCTAssertEqual(router.selectedTab, .settings)

        router.switchTab(to: .today)
        XCTAssertEqual(router.selectedTab, .today)
    }

    // MARK: - Push Navigation Tests

    func testPushToCurrentTab() {
        router.selectedTab = .lists
        let list = TestFactories.makeSampleList(id: 1, name: "Test List")

        router.push(.listDetail(list))

        XCTAssertEqual(router.listsPath.count, 1)
        XCTAssertTrue(router.todayPath.isEmpty)
        XCTAssertTrue(router.settingsPath.isEmpty)
    }

    func testPushToSpecificTab() {
        router.selectedTab = .today
        let list = TestFactories.makeSampleList(id: 1, name: "Test List")

        router.push(.listDetail(list), in: .lists)

        XCTAssertEqual(router.listsPath.count, 1)
        XCTAssertEqual(router.selectedTab, .lists)
    }

    func testPushMultipleRoutes() {
        router.selectedTab = .lists
        let list1 = TestFactories.makeSampleList(id: 1, name: "List 1")
        let list2 = TestFactories.makeSampleList(id: 2, name: "List 2")

        router.push(.listDetail(list1))
        router.push(.listDetail(list2))

        XCTAssertEqual(router.listsPath.count, 2)
    }

    // MARK: - Pop Navigation Tests

    func testPopFromCurrentTab() {
        router.selectedTab = .lists
        let list = TestFactories.makeSampleList(id: 1, name: "Test List")
        router.push(.listDetail(list))

        XCTAssertEqual(router.listsPath.count, 1)

        router.pop()

        XCTAssertTrue(router.listsPath.isEmpty)
    }

    func testPopFromSpecificTab() {
        let list = TestFactories.makeSampleList(id: 1, name: "Test List")
        router.push(.listDetail(list), in: .lists)
        router.selectedTab = .today

        router.pop(in: .lists)

        XCTAssertTrue(router.listsPath.isEmpty)
    }

    func testPopFromEmptyPathDoesNothing() {
        router.selectedTab = .today
        XCTAssertTrue(router.todayPath.isEmpty)

        router.pop()

        XCTAssertTrue(router.todayPath.isEmpty)
    }

    // MARK: - Pop to Root Tests

    func testPopToRoot() {
        router.selectedTab = .lists
        let list1 = TestFactories.makeSampleList(id: 1, name: "List 1")
        let list2 = TestFactories.makeSampleList(id: 2, name: "List 2")
        router.push(.listDetail(list1))
        router.push(.listDetail(list2))

        XCTAssertEqual(router.listsPath.count, 2)

        router.popToRoot()

        XCTAssertTrue(router.listsPath.isEmpty)
    }

    func testPopToRootInSpecificTab() {
        let list = TestFactories.makeSampleList(id: 1, name: "Test List")
        router.push(.listDetail(list), in: .lists)
        router.selectedTab = .today

        router.popToRoot(in: .lists)

        XCTAssertTrue(router.listsPath.isEmpty)
    }

    // MARK: - Sheet Presentation Tests

    func testPresentSheet() {
        router.present(.createList)

        XCTAssertNotNil(router.activeSheet)
        if case .createList = router.activeSheet {
            // Success
        } else {
            XCTFail("Expected createList sheet")
        }
    }

    func testDismissSheet() {
        router.present(.createList)
        XCTAssertNotNil(router.activeSheet)

        router.dismissSheet()

        XCTAssertNil(router.activeSheet)
    }

    func testDismissSheetClearsCallbacks() {
        var callbackCalled = false
        router.sheetCallbacks.onListCreated = {
            callbackCalled = true
        }
        router.present(.createList)

        router.dismissSheet()

        XCTAssertNil(router.sheetCallbacks.onListCreated)
        XCTAssertFalse(callbackCalled)
    }

    func testPresentDifferentSheetTypes() {
        let list = TestFactories.makeSampleList(id: 1, name: "Test")
        let task = TestFactories.makeSampleTask(id: 1, title: "Task")

        router.present(.createList)
        if case .createList = router.activeSheet {} else { XCTFail("Expected createList") }

        router.present(.editList(list))
        if case .editList(let l) = router.activeSheet {
            XCTAssertEqual(l.id, list.id)
        } else { XCTFail("Expected editList") }

        router.present(.taskDetail(task, listName: "List"))
        if case .taskDetail(let t, let name) = router.activeSheet {
            XCTAssertEqual(t.id, task.id)
            XCTAssertEqual(name, "List")
        } else { XCTFail("Expected taskDetail") }

        router.present(.acceptInvite("ABC123"))
        if case .acceptInvite(let code) = router.activeSheet {
            XCTAssertEqual(code, "ABC123")
        } else { XCTFail("Expected acceptInvite") }
    }

    // MARK: - Convenience Method Tests

    func testNavigateToList() {
        router.selectedTab = .today
        let list = TestFactories.makeSampleList(id: 1, name: "Test List")

        router.navigateToList(list)

        XCTAssertEqual(router.selectedTab, .lists)
        XCTAssertEqual(router.listsPath.count, 1)
        if case .listDetail(let l) = router.listsPath.first {
            XCTAssertEqual(l.id, list.id)
        } else {
            XCTFail("Expected listDetail route")
        }
    }

    func testPresentInvite() {
        router.presentInvite(code: "INVITE123")

        if case .acceptInvite(let code) = router.activeSheet {
            XCTAssertEqual(code, "INVITE123")
        } else {
            XCTFail("Expected acceptInvite sheet")
        }
    }

    // MARK: - Deep Link Tests

    func testHandleDeepLinkWhenReady() {
        router.markReady()

        router.handleDeepLink(.openToday)

        XCTAssertEqual(router.selectedTab, .today)
    }

    func testHandleDeepLinkOpenInvite() {
        router.markReady()

        router.handleDeepLink(.openInvite(code: "TEST123"))

        if case .acceptInvite(let code) = router.activeSheet {
            XCTAssertEqual(code, "TEST123")
        } else {
            XCTFail("Expected acceptInvite sheet")
        }
    }

    func testDeepLinkBufferedBeforeReady() {
        // Don't call markReady()
        router.handleDeepLink(.openInvite(code: "BUFFERED"))

        // Sheet should not be presented yet
        XCTAssertNil(router.activeSheet)

        // Now mark ready
        router.markReady()

        // Buffered deep link should be executed
        if case .acceptInvite(let code) = router.activeSheet {
            XCTAssertEqual(code, "BUFFERED")
        } else {
            XCTFail("Expected buffered deep link to be executed")
        }
    }

    // MARK: - Sheet Callbacks Tests

    func testSheetCallbacksInitiallyNil() {
        XCTAssertNil(router.sheetCallbacks.onTaskCreated)
        XCTAssertNil(router.sheetCallbacks.onTaskCompleted)
        XCTAssertNil(router.sheetCallbacks.onTaskDeleted)
        XCTAssertNil(router.sheetCallbacks.onTaskUpdated)
        XCTAssertNil(router.sheetCallbacks.onSubtaskCreated)
        XCTAssertNil(router.sheetCallbacks.onSubtaskUpdated)
        XCTAssertNil(router.sheetCallbacks.onListCreated)
        XCTAssertNil(router.sheetCallbacks.onListUpdated)
        XCTAssertNil(router.sheetCallbacks.onListJoined)
    }

    func testSheetCallbacksCanBeSet() async {
        var taskCreatedCalled = false

        router.sheetCallbacks.onTaskCreated = {
            taskCreatedCalled = true
        }

        await router.sheetCallbacks.onTaskCreated?()

        XCTAssertTrue(taskCreatedCalled)
    }
}
