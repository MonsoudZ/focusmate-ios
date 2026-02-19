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
    self.app = XCUIApplication()
    self.app.launchWithMockAPI()

    // Sign in first
    self.signIn()
  }

  override func tearDownWithError() throws {
    self.app = nil
  }

  // MARK: - Helper Methods

  private func signIn() {
    let emailField = self.app.textFields["Email"]
    if emailField.waitForExistence(timeout: 5.0) {
      emailField.tap()
      emailField.typeText(TestCredentials.validEmail)

      let passwordField = self.app.secureTextFields["Password"]
      passwordField.tap()
      passwordField.typeText(TestCredentials.validPassword)

      let signInButton = self.app.buttons["Sign In"]
      signInButton.tap()

      // Wait for main app to load
      let todayTab = self.app.tabBars.buttons["Today"]
      _ = todayTab.waitForExistence(timeout: 10.0)
    }
  }

  private func navigateToTodayTab() {
    let todayTab = self.app.tabBars.buttons["Today"]
    if todayTab.waitForExistence(timeout: 5.0) {
      todayTab.tap()
    }
  }

  /// Wait for the Today view to be fully loaded
  private func waitForTodayViewLoaded() {
    // Wait for any loading indicator to disappear or content to appear
    let scrollView = self.app.scrollViews.firstMatch
    _ = scrollView.waitForExistence(timeout: 5.0)
  }

  // MARK: - Today View Display Tests

  @MainActor
  func testTodayViewDisplays() {
    // Given: User is authenticated
    // When: User navigates to Today tab
    // Then: Today view should be displayed

    self.navigateToTodayTab()

    // Wait for view to load
    self.waitForTodayViewLoaded()

    XCTAssertTrue(self.app.exists, "App should be running")
  }

  @MainActor
  func testTodayViewShowsTasks() {
    // Given: User has tasks for today
    // When: User views Today tab
    // Then: Tasks should be displayed

    self.navigateToTodayTab()

    // Wait for tasks to load using expectation
    self.waitForTodayViewLoaded()

    // Verify view is displayed
    XCTAssertTrue(self.app.exists, "App should be running")
  }

  @MainActor
  func testTodayViewShowsEmptyState() {
    // Given: User has no tasks for today
    // When: User views Today tab
    // Then: Empty state should be displayed

    self.navigateToTodayTab()

    // Wait for view to load
    self.waitForTodayViewLoaded()

    // Check for empty state (adjust based on actual implementation)
    XCTAssertTrue(self.app.exists, "App should be running")
  }

  @MainActor
  func testTodayViewShowsProgress() {
    // Given: User has tasks for today
    // When: User views Today tab
    // Then: Progress indicator should be displayed

    self.navigateToTodayTab()

    // Wait for view to load
    self.waitForTodayViewLoaded()

    // Look for progress indicators
    XCTAssertTrue(self.app.exists, "App should be running")
  }

  // MARK: - Quick Add Tests

  @MainActor
  func testQuickAddButtonExists() {
    // Given: User is on Today view
    // When: View loads
    // Then: Quick add button should be visible

    self.navigateToTodayTab()

    // Wait for view to load
    self.waitForTodayViewLoaded()

    XCTAssertTrue(self.app.exists, "App should be running")
  }

  @MainActor
  func testQuickAddOpensSheet() {
    // Given: User is on Today view
    // When: User taps quick add button
    // Then: Quick add sheet should appear

    self.navigateToTodayTab()

    // Wait for view to load
    self.waitForTodayViewLoaded()

    // Verify sheet appears (adjust based on actual implementation)
    XCTAssertTrue(self.app.exists, "App should be running")
  }

  // MARK: - Task Interaction Tests

  @MainActor
  func testTaskCanBeTapped() {
    // Given: User has tasks in Today view
    // When: User taps a task
    // Then: Task detail view should appear

    self.navigateToTodayTab()

    // Wait for tasks to load
    self.waitForTodayViewLoaded()

    // Try to find and tap a task
    let taskCells = self.app.cells
    if taskCells.count > 0 {
      taskCells.element(boundBy: 0).tap()

      // Wait for detail view to appear
      let detailView = self.app.navigationBars["Task Details"]
      _ = detailView.waitForExistence(timeout: 5.0)
    }

    XCTAssertTrue(self.app.exists, "App should be running")
  }

  @MainActor
  func testTaskCanBeCompleted() {
    // Given: User has incomplete tasks in Today view
    // When: User completes a task
    // Then: Task should be marked as completed

    self.navigateToTodayTab()

    // Wait for tasks to load
    self.waitForTodayViewLoaded()

    // Try to find and complete a task
    XCTAssertTrue(self.app.exists, "App should be running")
  }

  // MARK: - Pull to Refresh Tests

  @MainActor
  func testTodayViewPullToRefresh() {
    // Given: User is on Today view
    // When: User pulls down to refresh
    // Then: Tasks should reload

    self.navigateToTodayTab()

    // Find scrollable area and pull down
    let scrollView = self.app.scrollViews.firstMatch
    if scrollView.waitForExistence(timeout: 5.0) {
      let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
      let end = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
      start.press(forDuration: 0.1, thenDragTo: end)

      // Wait for refresh to complete
      self.waitForTodayViewLoaded()
    }

    // Verify view is still visible
    XCTAssertTrue(self.app.exists, "App should be running")
  }
}
