import XCTest

/// UI Performance tests for app launch and navigation
/// These tests measure real-world performance with the full app stack
final class LaunchPerformanceTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Launch Performance

    /// Measures cold launch time to first interactive screen
    func testColdLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
    }

    /// Measures launch time with specific launch arguments
    func testLaunchPerformanceWithMetrics() throws {
        let metrics: [XCTMetric] = [
            XCTApplicationLaunchMetric(),
            XCTMemoryMetric(),
            XCTCPUMetric()
        ]

        let options = XCTMeasureOptions()
        options.iterationCount = 3

        measure(metrics: metrics, options: options) {
            app.launch()
            app.terminate()
        }
    }

    // MARK: - Navigation Performance

    /// Measures time to navigate between tabs
    func testTabNavigationPerformance() throws {
        app.launch()

        // Wait for app to be ready
        let todayTab = app.tabBars.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 10))

        measure {
            // Navigate through tabs
            app.tabBars.buttons["Lists"].tap()
            app.tabBars.buttons["Settings"].tap()
            app.tabBars.buttons["Today"].tap()
        }
    }

    // MARK: - Memory During Navigation

    /// Measures memory impact of repeated navigation
    func testMemoryDuringRepeatedNavigation() throws {
        app.launch()

        let todayTab = app.tabBars.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 10))

        measure(metrics: [XCTMemoryMetric()]) {
            for _ in 0..<5 {
                app.tabBars.buttons["Lists"].tap()
                app.tabBars.buttons["Settings"].tap()
                app.tabBars.buttons["Today"].tap()
            }
        }
    }

    // MARK: - Scroll Performance

    /// Measures scroll performance on Today view
    /// Note: Requires tasks to be present in the account
    func testTodayViewScrollPerformance() throws {
        app.launch()

        let todayTab = app.tabBars.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 10))
        todayTab.tap()

        // Wait for content to load
        sleep(2)

        // Find a scrollable element
        let scrollView = app.scrollViews.firstMatch

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
    func testAnimationPerformance() throws {
        app.launch()

        let todayTab = app.tabBars.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 10))

        // Use the animation hitches metric if available
        if #available(iOS 15.0, *) {
            measure(metrics: [XCTOSSignpostMetric.animationHitchMetric]) {
                // Trigger animations by tab switching
                app.tabBars.buttons["Lists"].tap()
                app.tabBars.buttons["Today"].tap()
            }
        }
    }
}
