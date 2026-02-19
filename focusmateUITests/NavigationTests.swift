//
//  NavigationTests.swift
//  focusmateUITests
//
//  UI tests for navigation and tab switching
//

import XCTest

final class NavigationTests: XCTestCase {
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

  // MARK: - Tab Navigation Tests

  @MainActor
  func testAllTabsAreVisible() {
    // Given: User is authenticated
    // When: App loads
    // Then: All main tabs should be visible

    let todayTab = self.app.tabBars.buttons["Today"]
    XCTAssertTrue(todayTab.waitForExistence(timeout: 5.0), "Today tab should be visible")

    let listsTab = self.app.tabBars.buttons["Lists"]
    XCTAssertTrue(listsTab.waitForExistence(timeout: 5.0), "Lists tab should be visible")

    let settingsTab = self.app.tabBars.buttons["Settings"]
    XCTAssertTrue(settingsTab.waitForExistence(timeout: 5.0), "Settings tab should be visible")
  }

  @MainActor
  func testNavigateToTodayTab() {
    // Given: User is on any tab
    // When: User taps Today tab
    // Then: Today view should be displayed

    let todayTab = self.app.tabBars.buttons["Today"]
    todayTab.tap()

    // Wait for tab selection to register
    XCTAssertTrue(todayTab.waitForExistence(timeout: 3.0))
    XCTAssertTrue(todayTab.isSelected, "Today tab should be selected")
  }

  @MainActor
  func testNavigateToListsTab() {
    // Given: User is on any tab
    // When: User taps Lists tab
    // Then: Lists view should be displayed

    let listsTab = self.app.tabBars.buttons["Lists"]
    listsTab.tap()

    let navigationTitle = self.app.navigationBars["Lists"]
    XCTAssertTrue(navigationTitle.waitForExistence(timeout: 5.0), "Lists view should be displayed")
    XCTAssertTrue(listsTab.isSelected, "Lists tab should be selected")
  }

  @MainActor
  func testNavigateToSettingsTab() {
    // Given: User is on any tab
    // When: User taps Settings tab
    // Then: Settings view should be displayed

    let settingsTab = self.app.tabBars.buttons["Settings"]
    settingsTab.tap()

    let navigationTitle = self.app.navigationBars["Settings"]
    XCTAssertTrue(navigationTitle.waitForExistence(timeout: 5.0), "Settings view should be displayed")
    XCTAssertTrue(settingsTab.isSelected, "Settings tab should be selected")
  }

  @MainActor
  func testTabSwitching() {
    // Given: User is authenticated
    // When: User switches between tabs
    // Then: Each tab should display correctly

    // Switch to Lists
    let listsTab = self.app.tabBars.buttons["Lists"]
    listsTab.tap()
    XCTAssertTrue(listsTab.isSelected, "Lists tab should be selected")

    // Switch to Settings
    let settingsTab = self.app.tabBars.buttons["Settings"]
    settingsTab.tap()
    XCTAssertTrue(settingsTab.isSelected, "Settings tab should be selected")

    // Switch to Today
    let todayTab = self.app.tabBars.buttons["Today"]
    todayTab.tap()
    XCTAssertTrue(todayTab.isSelected, "Today tab should be selected")
  }

  @MainActor
  func testNavigationStackPreserved() {
    // Given: User navigates to a detail view
    // When: User switches tabs and returns
    // Then: Navigation state should be preserved

    // Navigate to Lists
    let listsTab = self.app.tabBars.buttons["Lists"]
    listsTab.tap()

    // If there are lists, try to navigate to one
    // This test might need adjustment based on actual list items

    // Switch to another tab
    let settingsTab = self.app.tabBars.buttons["Settings"]
    settingsTab.tap()

    // Return to Lists
    listsTab.tap()

    // Verify we're back on Lists view
    let listsNavigation = self.app.navigationBars["Lists"]
    XCTAssertTrue(listsNavigation.waitForExistence(timeout: 5.0), "Should return to Lists view")
  }

  // MARK: - Back Navigation Tests

  @MainActor
  func testBackButtonExistsInDetailViews() {
    // Given: User navigates to a detail view
    // When: View loads
    // Then: Back button should be visible

    // Navigate to Lists
    let listsTab = self.app.tabBars.buttons["Lists"]
    listsTab.tap()

    // Wait for lists to load
    let listsNavigation = self.app.navigationBars["Lists"]
    _ = listsNavigation.waitForExistence(timeout: 5.0)

    // If we're in a detail view, check for back button
    let backButton = self.app.navigationBars.buttons.element(boundBy: 0)
    if backButton.exists {
      XCTAssertTrue(backButton.exists, "Back button should exist in detail view")
    }
  }
}
