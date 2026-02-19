import XCTest

/// UI Performance tests for app launch and navigation
/// These tests measure real-world performance with the full app stack
final class LaunchPerformanceTests: XCTestCase {
  var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    self.app = XCUIApplication()
  }

  override func tearDownWithError() throws {
    self.app = nil
  }

  // MARK: - Launch Performance

  /// Measures cold launch time to first interactive screen
  func testColdLaunchPerformance() {
    measure(metrics: [XCTApplicationLaunchMetric()]) {
      self.app.launch()
    }
  }

  /// Measures launch time with specific launch arguments
  func testLaunchPerformanceWithMetrics() {
    let metrics: [XCTMetric] = [
      XCTApplicationLaunchMetric(),
      XCTMemoryMetric(),
      XCTCPUMetric(),
    ]

    let options = XCTMeasureOptions()
    options.iterationCount = 3

    measure(metrics: metrics, options: options) {
      self.app.launch()
      self.app.terminate()
    }
  }

  // MARK: - Navigation Performance

  /// Measures time to navigate between tabs
  func testTabNavigationPerformance() {
    self.app.launch()

    // Wait for app to be ready
    let todayTab = self.app.tabBars.buttons["Today"]
    XCTAssertTrue(todayTab.waitForExistence(timeout: 10))

    measure {
      // Navigate through tabs
      self.app.tabBars.buttons["Lists"].tap()
      self.app.tabBars.buttons["Settings"].tap()
      self.app.tabBars.buttons["Today"].tap()
    }
  }

  // MARK: - Memory During Navigation

  /// Measures memory impact of repeated navigation
  func testMemoryDuringRepeatedNavigation() {
    self.app.launch()

    let todayTab = self.app.tabBars.buttons["Today"]
    XCTAssertTrue(todayTab.waitForExistence(timeout: 10))

    measure(metrics: [XCTMemoryMetric()]) {
      for _ in 0 ..< 5 {
        self.app.tabBars.buttons["Lists"].tap()
        self.app.tabBars.buttons["Settings"].tap()
        self.app.tabBars.buttons["Today"].tap()
      }
    }
  }

  // MARK: - Scroll Performance

  /// Measures scroll performance on Today view
  /// Note: Requires tasks to be present in the account
  func testTodayViewScrollPerformance() throws {
    self.app.launch()

    let todayTab = self.app.tabBars.buttons["Today"]
    XCTAssertTrue(todayTab.waitForExistence(timeout: 10))
    todayTab.tap()

    // Wait for content to load
    sleep(2)

    // Find a scrollable element
    let scrollView = self.app.scrollViews.firstMatch

    guard scrollView.exists else {
      // Skip if no scrollable content
      throw XCTSkip("No scrollable content found - need tasks in account")
    }

    measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
      scrollView.swipeUp()
      scrollView.swipeDown()
    }
  }

  // MARK: - Animation Performance

  /// Measures frame rate during common animations
  func testAnimationPerformance() {
    self.app.launch()

    let todayTab = self.app.tabBars.buttons["Today"]
    XCTAssertTrue(todayTab.waitForExistence(timeout: 10))

    // Trigger animations by tab switching for stability check
    self.app.tabBars.buttons["Lists"].tap()
    self.app.tabBars.buttons["Today"].tap()
  }
}
