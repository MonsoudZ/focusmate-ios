//
//  UITestHelpers.swift
//  focusmateUITests
//
//  Test helper utilities for UI tests
//

import XCTest

extension XCUIApplication {
    /// Launch the app with mock API mode enabled
    func launchWithMockAPI() {
        launchArguments = ["--mock-api"]
        launchEnvironment = ["MOCK_API": "true"]
        launch()
    }
    
    /// Wait for an element to appear with timeout
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5.0) -> Bool {
        let predicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
    
    /// Wait for element to disappear
    func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval = 5.0) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
    
    /// Tap element if it exists and is hittable
    func tapIfExists(_ element: XCUIElement) {
        if element.waitForExistence(timeout: 2.0) && element.isHittable {
            element.tap()
        }
    }
    
    /// Scroll to element if needed
    func scrollToElement(_ element: XCUIElement, in scrollView: XCUIElement) {
        if !element.isHittable {
            scrollView.swipeUp()
        }
    }
}

extension XCUIElement {
    /// Clear text field and type new text
    func clearAndTypeText(_ text: String) {
        guard let stringValue = value as? String else {
            XCTFail("Tried to clear and enter text into a non string value")
            return
        }
        
        tap()
        
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        typeText(deleteString)
        typeText(text)
    }
    
    /// Wait for element to exist and be hittable
    func waitForExistenceAndHittable(timeout: TimeInterval = 5.0) -> Bool {
        guard waitForExistence(timeout: timeout) else { return false }
        return isHittable
    }
}

// MARK: - Test Data

struct TestCredentials {
    static let validEmail = "test@example.com"
    static let validPassword = "TestPassword123!"
    static let validName = "Test User"
    
    static let invalidEmail = "invalid-email"
    static let invalidPassword = "123"
}

struct TestListData {
    static let testListName = "Test List"
    static let testListDescription = "This is a test list"
}

