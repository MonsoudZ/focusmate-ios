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

final class focusmateUITests: XCTestCase {
  var app: XCUIApplication!
  
  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
  }

  override func tearDownWithError() throws {
    app = nil
  }

  @MainActor
  func testLaunchPerformance() throws {
    // This measures how long it takes to launch your application.
    measure(metrics: [XCTApplicationLaunchMetric()]) {
      let app = XCUIApplication()
      app.launch()
    }
  }
  
  @MainActor
  func testAppLaunches() throws {
    // Basic smoke test: verify app launches successfully
    app.launch()
    
    // Verify app is running
    XCTAssertTrue(app.exists, "App should launch successfully")
    
    // Verify initial state (should show sign in if not authenticated)
    sleep(2)
    XCTAssertTrue(app.exists, "App should be running after launch")
  }
}
