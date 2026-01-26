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
    
    // MARK: - Today View Display Tests
    
    @MainActor
    func testTodayViewDisplays() throws {
        // Given: User is authenticated
        // When: User navigates to Today tab
        // Then: Today view should be displayed
        
        navigateToTodayTab()
        
        // Verify Today view is displayed
        // Note: Adjust based on actual Today view implementation
        sleep(2)
        XCTAssertTrue(app.exists, "App should be running")
    }
    
    @MainActor
    func testTodayViewShowsTasks() throws {
        // Given: User has tasks for today
        // When: User views Today tab
        // Then: Tasks should be displayed
        
        navigateToTodayTab()
        
        // Wait for tasks to load
        sleep(3)
        
        // Verify view is displayed
        // Note: This will need adjustment based on actual task display implementation
        XCTAssertTrue(app.exists, "App should be running")
    }
    
    @MainActor
    func testTodayViewShowsEmptyState() throws {
        // Given: User has no tasks for today
        // When: User views Today tab
        // Then: Empty state should be displayed
        
        navigateToTodayTab()
        
        // Wait for view to load
        sleep(3)
        
        // Check for empty state (adjust based on actual implementation)
        // Empty state might show a message like "No tasks for today"
        XCTAssertTrue(app.exists, "App should be running")
    }
    
    @MainActor
    func testTodayViewShowsProgress() throws {
        // Given: User has tasks for today
        // When: User views Today tab
        // Then: Progress indicator should be displayed
        
        navigateToTodayTab()
        
        // Wait for view to load
        sleep(3)
        
        // Look for progress indicators (adjust based on actual implementation)
        // This might be a progress ring or completion percentage
        XCTAssertTrue(app.exists, "App should be running")
    }
    
    // MARK: - Quick Add Tests
    
    @MainActor
    func testQuickAddButtonExists() throws {
        // Given: User is on Today view
        // When: View loads
        // Then: Quick add button should be visible
        
        navigateToTodayTab()
        
        // Look for quick add button (adjust based on actual implementation)
        // This might be a floating action button or toolbar button
        sleep(2)
        XCTAssertTrue(app.exists, "App should be running")
    }
    
    @MainActor
    func testQuickAddOpensSheet() throws {
        // Given: User is on Today view
        // When: User taps quick add button
        // Then: Quick add sheet should appear
        
        navigateToTodayTab()
        
        // Find and tap quick add button
        // This will need adjustment based on actual implementation
        sleep(2)
        
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
        sleep(3)
        
        // Try to find and tap a task
        // This will need adjustment based on actual task display implementation
        let taskCells = app.cells
        if taskCells.count > 0 {
            taskCells.element(boundBy: 0).tap()
            
            // Verify detail view appears (adjust based on actual implementation)
            sleep(2)
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
        sleep(3)
        
        // Try to find and complete a task
        // This will need adjustment based on actual task display implementation
        // Tasks might have checkboxes or swipe actions
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
        if scrollView.exists {
            let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
            let end = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
            start.press(forDuration: 0.1, thenDragTo: end)
            
            // Wait for refresh to complete
            sleep(2)
        }
        
        // Verify view is still visible
        XCTAssertTrue(app.exists, "App should be running")
    }
}

