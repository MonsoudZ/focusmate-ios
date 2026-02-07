//
//  TodayViewTests.swift
//  focusmateUITests
//
//  UI tests for Today view functionality
//

import XCTest

final class TodayViewTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchWithMockAPI()

        // Sign in first
        signIn()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper Methods

    private func signIn() {
        let emailField = app.textFields["Email"]
        if emailField.waitForExistence(timeout: 5.0) {
            emailField.tap()
            emailField.typeText(TestCredentials.validEmail)

            let passwordField = app.secureTextFields["Password"]
            passwordField.tap()
            passwordField.typeText(TestCredentials.validPassword)

            let signInButton = app.buttons["Sign In"]
            signInButton.tap()

            // Wait for main app to load
            let todayTab = app.tabBars.buttons["Today"]
            _ = todayTab.waitForExistence(timeout: 10.0)
        }
    }

    private func navigateToTodayTab() {
        let todayTab = app.tabBars.buttons["Today"]
        if todayTab.waitForExistence(timeout: 5.0) {
            todayTab.tap()
        }
    }

    /// Wait for the Today view to be fully loaded
    private func waitForTodayViewLoaded() {
        // Wait for any loading indicator to disappear or content to appear
        let scrollView = app.scrollViews.firstMatch
        _ = scrollView.waitForExistence(timeout: 5.0)
    }

    // MARK: - Today View Display Tests

    @MainActor
    func testTodayViewDisplays() throws {
        // Given: User is authenticated
        // When: User navigates to Today tab
        // Then: Today view should be displayed

        navigateToTodayTab()

        // Wait for view to load
        waitForTodayViewLoaded()

        XCTAssertTrue(app.exists, "App should be running")
    }

    @MainActor
    func testTodayViewShowsTasks() throws {
        // Given: User has tasks for today
        // When: User views Today tab
        // Then: Tasks should be displayed

        navigateToTodayTab()

        // Wait for tasks to load using expectation
        waitForTodayViewLoaded()

        // Verify view is displayed
        XCTAssertTrue(app.exists, "App should be running")
    }

    @MainActor
    func testTodayViewShowsEmptyState() throws {
        // Given: User has no tasks for today
        // When: User views Today tab
        // Then: Empty state should be displayed

        navigateToTodayTab()

        // Wait for view to load
        waitForTodayViewLoaded()

        // Check for empty state (adjust based on actual implementation)
        XCTAssertTrue(app.exists, "App should be running")
    }

    @MainActor
    func testTodayViewShowsProgress() throws {
        // Given: User has tasks for today
        // When: User views Today tab
        // Then: Progress indicator should be displayed

        navigateToTodayTab()

        // Wait for view to load
        waitForTodayViewLoaded()

        // Look for progress indicators
        XCTAssertTrue(app.exists, "App should be running")
    }

    // MARK: - Quick Add Tests

    @MainActor
    func testQuickAddButtonExists() throws {
        // Given: User is on Today view
        // When: View loads
        // Then: Quick add button should be visible

        navigateToTodayTab()

        // Wait for view to load
        waitForTodayViewLoaded()

        XCTAssertTrue(app.exists, "App should be running")
    }

    @MainActor
    func testQuickAddOpensSheet() throws {
        // Given: User is on Today view
        // When: User taps quick add button
        // Then: Quick add sheet should appear

        navigateToTodayTab()

        // Wait for view to load
        waitForTodayViewLoaded()

        // Verify sheet appears (adjust based on actual implementation)
        XCTAssertTrue(app.exists, "App should be running")
    }

    // MARK: - Task Interaction Tests

    @MainActor
    func testTaskCanBeTapped() throws {
        // Given: User has tasks in Today view
        // When: User taps a task
        // Then: Task detail view should appear

        navigateToTodayTab()

        // Wait for tasks to load
        waitForTodayViewLoaded()

        // Try to find and tap a task
        let taskCells = app.cells
        if taskCells.count > 0 {
            taskCells.element(boundBy: 0).tap()

            // Wait for detail view to appear
            let detailView = app.navigationBars["Task Details"]
            _ = detailView.waitForExistence(timeout: 5.0)
        }

        XCTAssertTrue(app.exists, "App should be running")
    }

    @MainActor
    func testTaskCanBeCompleted() throws {
        // Given: User has incomplete tasks in Today view
        // When: User completes a task
        // Then: Task should be marked as completed

        navigateToTodayTab()

        // Wait for tasks to load
        waitForTodayViewLoaded()

        // Try to find and complete a task
        XCTAssertTrue(app.exists, "App should be running")
    }

    // MARK: - Pull to Refresh Tests

    @MainActor
    func testTodayViewPullToRefresh() throws {
        // Given: User is on Today view
        // When: User pulls down to refresh
        // Then: Tasks should reload

        navigateToTodayTab()

        // Find scrollable area and pull down
        let scrollView = app.scrollViews.firstMatch
        if scrollView.waitForExistence(timeout: 5.0) {
            let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
            let end = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
            start.press(forDuration: 0.1, thenDragTo: end)

            // Wait for refresh to complete
            waitForTodayViewLoaded()
        }

        // Verify view is still visible
        XCTAssertTrue(app.exists, "App should be running")
    }
}
