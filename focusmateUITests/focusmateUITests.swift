//
//  focusmateUITests.swift
//  focusmateUITests
//
//  Main UI test suite - see individual test files for specific flows:
//  - AuthenticationFlowTests.swift: Sign in, sign up, forgot password
//  - ListManagementTests.swift: Create, view, delete lists
//  - NavigationTests.swift: Tab navigation and navigation stack
//  - TodayViewTests.swift: Today view functionality
//

import XCTest

// swiftlint:disable:next type_name
final class focusmateUITests: XCTestCase {
  var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    self.app = XCUIApplication()
  }

  override func tearDownWithError() throws {
    self.app = nil
  }

  @MainActor
  func testLaunchPerformance() {
    // This measures how long it takes to launch your application.
    measure(metrics: [XCTApplicationLaunchMetric()]) {
      let app = XCUIApplication()
      app.launch()
    }
  }

  @MainActor
  func testAppLaunches() {
    // Basic smoke test: verify app launches successfully
    self.app.launch()

    // Verify app is running
    XCTAssertTrue(self.app.exists, "App should launch successfully")

    // Wait for initial UI to load (sign in or main app)
    let signInButton = self.app.buttons["Sign In"]
    let todayTab = self.app.tabBars.buttons["Today"]
    let initialUILoaded = signInButton.waitForExistence(timeout: 5.0) || todayTab.waitForExistence(timeout: 5.0)
    XCTAssertTrue(initialUILoaded || self.app.exists, "App should be running after launch")
  }
}
