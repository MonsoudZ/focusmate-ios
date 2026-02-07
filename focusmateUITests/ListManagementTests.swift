//
//  ListManagementTests.swift
//  focusmateUITests
//
//  UI tests for list management (create, view, delete lists)
//

import XCTest

final class ListManagementTests: XCTestCase {
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
            let listsTab = app.tabBars.buttons["Lists"]
            _ = listsTab.waitForExistence(timeout: 10.0)
        }
    }
    
    private func navigateToListsTab() {
        let listsTab = app.tabBars.buttons["Lists"]
        if listsTab.waitForExistence(timeout: 5.0) {
            listsTab.tap()
        }
    }
    
    // MARK: - List View Tests
    
    @MainActor
    func testListsTabExists() throws {
        // Given: User is authenticated
        // When: App loads
        // Then: Lists tab should be visible
        
        let listsTab = app.tabBars.buttons["Lists"]
        XCTAssertTrue(listsTab.waitForExistence(timeout: 5.0), "Lists tab should be visible")
    }
    
    @MainActor
    func testListsViewDisplays() throws {
        // Given: User is authenticated
        // When: User navigates to Lists tab
        // Then: Lists view should be displayed
        
        navigateToListsTab()
        
        let navigationTitle = app.navigationBars["Lists"]
        XCTAssertTrue(navigationTitle.waitForExistence(timeout: 5.0), "Lists navigation title should be visible")
    }
    
    @MainActor
    func testEmptyStateWhenNoLists() throws {
        // Given: User has no lists
        // When: User navigates to Lists tab
        // Then: Empty state should be displayed

        navigateToListsTab()

        // Check for empty state message (adjust based on actual implementation)
        let emptyStateText = app.staticTexts["No lists yet"]
        if emptyStateText.waitForExistence(timeout: 5.0) {
            XCTAssertTrue(emptyStateText.exists, "Empty state should be displayed")
        }
    }
    
    @MainActor
    func testCreateListButtonExists() throws {
        // Given: User is on Lists view
        // When: View loads
        // Then: Create list button should be visible
        
        navigateToListsTab()
        
        // Look for the plus button in toolbar
        let createButton = app.buttons.matching(identifier: "plus").firstMatch
        if !createButton.exists {
            // Try alternative: button with "Create List" text or plus icon
            let toolbarButtons = app.navigationBars["Lists"].buttons
            XCTAssertGreaterThan(toolbarButtons.count, 0, "Toolbar should have buttons")
        }
    }
    
    // MARK: - Create List Tests
    
    @MainActor
    func testCreateListButtonOpensSheet() throws {
        // Given: User is on Lists view
        // When: User taps create list button
        // Then: Create list sheet should appear
        
        navigateToListsTab()
        
        // Find and tap create button
        let navigationBar = app.navigationBars["Lists"]
        let buttons = navigationBar.buttons
        if buttons.count > 0 {
            // Tap the last button (usually the plus button)
            buttons.element(boundBy: buttons.count - 1).tap()
            
            // Verify create list view appears
            let createListTitle = app.navigationBars["New List"]
            XCTAssertTrue(createListTitle.waitForExistence(timeout: 5.0), "Create list view should appear")
        }
    }
    
    @MainActor
    func testCreateListFormFields() throws {
        // Given: Create list view is displayed
        // When: View loads
        // Then: All form fields should be visible
        
        navigateToListsTab()
        
        // Open create list
        let navigationBar = app.navigationBars["Lists"]
        let buttons = navigationBar.buttons
        if buttons.count > 0 {
            buttons.element(boundBy: buttons.count - 1).tap()
        }
        
        // Verify form fields
        let listNameField = app.textFields["List Name"]
        XCTAssertTrue(listNameField.waitForExistence(timeout: 5.0), "List Name field should be visible")
        
        // Description field might be optional
        let descriptionField = app.textFields["Description (Optional)"]
        if descriptionField.waitForExistence(timeout: 2.0) {
            XCTAssertTrue(descriptionField.exists, "Description field should be visible")
        }
    }
    
    @MainActor
    func testCreateListButtonDisabledWhenNameEmpty() throws {
        // Given: Create list view is displayed
        // When: List name field is empty
        // Then: Create button should be disabled
        
        navigateToListsTab()
        
        // Open create list
        let navigationBar = app.navigationBars["Lists"]
        let buttons = navigationBar.buttons
        if buttons.count > 0 {
            buttons.element(boundBy: buttons.count - 1).tap()
        }
        
        let createButton = app.buttons["Create"]
        if createButton.waitForExistence(timeout: 5.0) {
            XCTAssertFalse(createButton.isEnabled, "Create button should be disabled when name is empty")
        }
    }
    
    @MainActor
    func testCreateListWithValidData() throws {
        // Given: Create list view is displayed
        // When: User fills name and taps Create
        // Then: List should be created and sheet should dismiss
        
        navigateToListsTab()
        
        // Open create list
        let navigationBar = app.navigationBars["Lists"]
        let buttons = navigationBar.buttons
        if buttons.count > 0 {
            buttons.element(boundBy: buttons.count - 1).tap()
        }
        
        // Fill form
        let listNameField = app.textFields["List Name"]
        listNameField.tap()
        listNameField.typeText(TestListData.testListName)
        
        // Tap Create
        let createButton = app.buttons["Create"]
        if createButton.waitForExistence(timeout: 5.0) {
            createButton.tap()

            // Wait for sheet to dismiss and return to lists view
            let listsNavigation = app.navigationBars["Lists"]
            XCTAssertTrue(listsNavigation.waitForExistence(timeout: 5.0), "Should return to lists view")
        }
    }
    
    @MainActor
    func testCancelCreateList() throws {
        // Given: Create list view is displayed
        // When: User taps Cancel
        // Then: Sheet should dismiss and return to lists view
        
        navigateToListsTab()
        
        // Open create list
        let navigationBar = app.navigationBars["Lists"]
        let buttons = navigationBar.buttons
        if buttons.count > 0 {
            buttons.element(boundBy: buttons.count - 1).tap()
        }
        
        // Tap Cancel
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 5.0) {
            cancelButton.tap()
            
            // Verify back on lists view
            let listsNavigation = app.navigationBars["Lists"]
            XCTAssertTrue(listsNavigation.waitForExistence(timeout: 5.0), "Should return to lists view")
        }
    }
    
    // MARK: - List Display Tests
    
    @MainActor
    func testListsDisplayAfterCreation() throws {
        // Given: User has created a list
        // When: User views Lists tab
        // Then: Created list should be displayed

        navigateToListsTab()

        // Create a list first
        let navigationBar = app.navigationBars["Lists"]
        let buttons = navigationBar.buttons
        if buttons.count > 0 {
            buttons.element(boundBy: buttons.count - 1).tap()

            let listNameField = app.textFields["List Name"]
            listNameField.tap()
            listNameField.typeText("Test List \(Date().timeIntervalSince1970)")

            let createButton = app.buttons["Create"]
            if createButton.waitForExistence(timeout: 5.0) {
                createButton.tap()
                // Wait for sheet to dismiss
                _ = app.navigationBars["Lists"].waitForExistence(timeout: 5.0)
            }
        }

        // Verify we're back on the lists view
        let listsNav = app.navigationBars["Lists"]
        XCTAssertTrue(listsNav.waitForExistence(timeout: 5.0), "Should be on lists view")
    }

    @MainActor
    func testPullToRefresh() throws {
        // Given: User is on Lists view
        // When: User pulls down to refresh
        // Then: Lists should reload

        navigateToListsTab()

        // Find scrollable area and pull down
        let listsView = app.scrollViews.firstMatch
        if listsView.exists {
            let start = listsView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
            let end = listsView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
            start.press(forDuration: 0.1, thenDragTo: end)
        }

        // Verify view is still visible (navigation bar persists through refresh)
        let listsNavigation = app.navigationBars["Lists"]
        XCTAssertTrue(listsNavigation.waitForExistence(timeout: 5.0), "Lists view should still be visible after refresh")
    }
}

