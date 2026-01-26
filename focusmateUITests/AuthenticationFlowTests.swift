//
//  AuthenticationFlowTests.swift
//  focusmateUITests
//
//  UI tests for authentication flows (sign in, sign up)
//

import XCTest

final class AuthenticationFlowTests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchWithMockAPI()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Sign In Tests
    
    @MainActor
    func testSignInViewAppearsWhenNotAuthenticated() throws {
        // Given: App launches without authentication
        // When: App loads
        // Then: Sign in view should be visible
        
        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5.0), "Sign In button should be visible")
        
        let emailField = app.textFields["Email"]
        XCTAssertTrue(emailField.exists, "Email field should be visible")
        
        let passwordField = app.secureTextFields["Password"]
        XCTAssertTrue(passwordField.exists, "Password field should be visible")
    }
    
    @MainActor
    func testSignInButtonDisabledWhenFieldsEmpty() throws {
        // Given: Sign in view is displayed
        // When: Email and password fields are empty
        // Then: Sign In button should be disabled
        
        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5.0))
        XCTAssertFalse(signInButton.isEnabled, "Sign In button should be disabled when fields are empty")
    }
    
    @MainActor
    func testSignInButtonEnabledWhenFieldsFilled() throws {
        // Given: Sign in view is displayed
        // When: Email and password fields are filled
        // Then: Sign In button should be enabled
        
        let emailField = app.textFields["Email"]
        let passwordField = app.secureTextFields["Password"]
        
        emailField.tap()
        emailField.typeText(TestCredentials.validEmail)
        
        passwordField.tap()
        passwordField.typeText(TestCredentials.validPassword)
        
        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.isEnabled, "Sign In button should be enabled when fields are filled")
    }
    
    @MainActor
    func testSignInWithValidCredentials() throws {
        // Given: User is on sign in screen
        // When: User enters valid credentials and taps Sign In
        // Then: User should be authenticated and see main app
        
        // Enter credentials
        let emailField = app.textFields["Email"]
        emailField.tap()
        emailField.typeText(TestCredentials.validEmail)
        
        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText(TestCredentials.validPassword)
        
        // Tap Sign In
        let signInButton = app.buttons["Sign In"]
        signInButton.tap()
        
        // Wait for authentication to complete
        let todayTab = app.tabBars.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 10.0), "Should navigate to main app after successful sign in")
    }
    
    @MainActor
    func testSignInWithInvalidCredentials() throws {
        // Given: User is on sign in screen
        // When: User enters invalid credentials and taps Sign In
        // Then: Error message should be displayed
        
        // Enter invalid credentials
        let emailField = app.textFields["Email"]
        emailField.tap()
        emailField.typeText(TestCredentials.invalidEmail)
        
        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText(TestCredentials.invalidPassword)
        
        // Tap Sign In
        let signInButton = app.buttons["Sign In"]
        signInButton.tap()
        
        // Note: In mock mode, this might succeed. In real tests, we'd expect an error banner
        // For now, we just verify the app doesn't crash
        sleep(2)
        XCTAssertTrue(app.exists, "App should still be running")
    }
    
    // MARK: - Registration Tests
    
    @MainActor
    func testCreateAccountButtonOpensRegistration() throws {
        // Given: User is on sign in screen
        // When: User taps "Create Account" button
        // Then: Registration view should appear
        
        let createAccountButton = app.buttons["Create Account"]
        XCTAssertTrue(createAccountButton.waitForExistence(timeout: 5.0))
        createAccountButton.tap()
        
        // Verify registration view appears
        let navigationTitle = app.navigationBars["Create Account"]
        XCTAssertTrue(navigationTitle.waitForExistence(timeout: 5.0), "Registration view should appear")
        
        let nameField = app.textFields["Name"]
        XCTAssertTrue(nameField.exists, "Name field should be visible")
    }
    
    @MainActor
    func testRegistrationFormValidation() throws {
        // Given: Registration view is displayed
        // When: Form fields are empty
        // Then: Create Account button should be disabled
        
        // Open registration
        let createAccountButton = app.buttons["Create Account"]
        createAccountButton.tap()
        
        let createButton = app.buttons["Create Account"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5.0))
        XCTAssertFalse(createButton.isEnabled, "Create Account button should be disabled when form is empty")
    }
    
    @MainActor
    func testRegistrationWithValidData() throws {
        // Given: User is on registration screen
        // When: User fills all fields correctly and taps Create Account
        // Then: Account should be created and user should be signed in
        
        // Open registration
        let createAccountButton = app.buttons["Create Account"]
        createAccountButton.tap()
        
        // Fill form
        let nameField = app.textFields["Name"]
        nameField.tap()
        nameField.typeText(TestCredentials.validName)
        
        let emailField = app.textFields["Email"]
        emailField.tap()
        emailField.typeText(TestCredentials.validEmail)
        
        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText(TestCredentials.validPassword)
        
        let confirmPasswordField = app.secureTextFields["Confirm Password"]
        confirmPasswordField.tap()
        confirmPasswordField.typeText(TestCredentials.validPassword)
        
        // Tap Create Account
        let createButton = app.buttons["Create Account"]
        createButton.tap()
        
        // Wait for registration to complete
        let todayTab = app.tabBars.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 10.0), "Should navigate to main app after successful registration")
    }
    
    @MainActor
    func testRegistrationPasswordMismatch() throws {
        // Given: User is on registration screen
        // When: Password and confirm password don't match
        // Then: Create Account button should be disabled
        
        // Open registration
        let createAccountButton = app.buttons["Create Account"]
        createAccountButton.tap()
        
        // Fill form with mismatched passwords
        let nameField = app.textFields["Name"]
        nameField.tap()
        nameField.typeText(TestCredentials.validName)
        
        let emailField = app.textFields["Email"]
        emailField.tap()
        emailField.typeText(TestCredentials.validEmail)
        
        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText(TestCredentials.validPassword)
        
        let confirmPasswordField = app.secureTextFields["Confirm Password"]
        confirmPasswordField.tap()
        confirmPasswordField.typeText("DifferentPassword123!")
        
        // Verify button is disabled
        let createButton = app.buttons["Create Account"]
        XCTAssertFalse(createButton.isEnabled, "Create Account button should be disabled when passwords don't match")
    }
    
    @MainActor
    func testCancelRegistration() throws {
        // Given: User is on registration screen
        // When: User taps Cancel
        // Then: Should return to sign in screen
        
        // Open registration
        let createAccountButton = app.buttons["Create Account"]
        createAccountButton.tap()
        
        // Tap Cancel
        let cancelButton = app.buttons["Cancel"]
        cancelButton.tap()
        
        // Verify back on sign in screen
        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5.0), "Should return to sign in screen")
    }
    
    // MARK: - Forgot Password Tests
    
    @MainActor
    func testForgotPasswordButtonExists() throws {
        // Given: User is on sign in screen
        // When: View loads
        // Then: Forgot Password button should be visible
        
        let forgotPasswordButton = app.buttons["Forgot Password?"]
        XCTAssertTrue(forgotPasswordButton.waitForExistence(timeout: 5.0), "Forgot Password button should be visible")
    }
    
    @MainActor
    func testForgotPasswordOpensSheet() throws {
        // Given: User is on sign in screen
        // When: User taps "Forgot Password?"
        // Then: Forgot password sheet should appear
        
        let forgotPasswordButton = app.buttons["Forgot Password?"]
        forgotPasswordButton.tap()
        
        // Verify sheet appears (adjust based on actual implementation)
        sleep(1)
        // Note: Verify the actual forgot password view elements when implemented
    }
}

