# UI Tests Documentation

This directory contains comprehensive UI tests for the Focusmate iOS app, covering all critical user flows.

## Test Structure

### Test Files

1. **UITestHelpers.swift**
   - Common utilities and helper methods
   - Test data constants
   - Extension methods for XCUIApplication and XCUIElement

2. **AuthenticationFlowTests.swift**
   - Sign in flow tests
   - Registration flow tests
   - Form validation tests
   - Forgot password tests

3. **ListManagementTests.swift**
   - List creation tests
   - List display tests
   - List deletion tests
   - Pull-to-refresh tests

4. **NavigationTests.swift**
   - Tab navigation tests
   - Navigation stack preservation tests
   - Back button tests

5. **TodayViewTests.swift**
   - Today view display tests
   - Task interaction tests
   - Quick add functionality tests
   - Pull-to-refresh tests

6. **focusmateUITests.swift**
   - Basic launch and performance tests
   - Smoke tests

## Running Tests

### Run All UI Tests
```bash
xcodebuild test -scheme focusmate -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:focusmateUITests
```

### Run Specific Test Suite
```bash
# Authentication tests only
xcodebuild test -scheme focusmate -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:focusmateUITests/AuthenticationFlowTests

# List management tests only
xcodebuild test -scheme focusmate -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:focusmateUITests/ListManagementTests
```

### Run in Xcode
1. Open the project in Xcode
2. Select the `focusmateUITests` scheme
3. Press `Cmd+U` to run all tests
4. Or use the Test Navigator to run individual tests

## Test Configuration

### Mock API Mode
Tests automatically use mock API mode by calling `app.launchWithMockAPI()`. This allows tests to run without a live backend.

### Test Credentials
Test credentials are defined in `UITestHelpers.swift`:
- `TestCredentials.validEmail`
- `TestCredentials.validPassword`
- `TestCredentials.validName`

## Writing New Tests

### Best Practices

1. **Use Helper Methods**: Leverage `UITestHelpers` for common operations
   ```swift
   app.launchWithMockAPI()
   app.waitForElement(element)
   ```

2. **Wait for Elements**: Always wait for elements to appear before interacting
   ```swift
   let button = app.buttons["Sign In"]
   XCTAssertTrue(button.waitForExistence(timeout: 5.0))
   ```

3. **Use Descriptive Names**: Test names should clearly describe what they test
   ```swift
   func testSignInWithValidCredentials() throws
   ```

4. **Clean Up**: Use `setUp` and `tearDown` to ensure clean test state

5. **Isolate Tests**: Each test should be independent and not rely on other tests

### Example Test Structure

```swift
@MainActor
func testFeatureName() throws {
    // Given: Set up initial state
    navigateToFeature()
    
    // When: Perform action
    let button = app.buttons["Action"]
    button.tap()
    
    // Then: Verify expected result
    let result = app.staticTexts["Expected Result"]
    XCTAssertTrue(result.waitForExistence(timeout: 5.0))
}
```

## Known Limitations

1. **SwiftUI Element Identification**: Some SwiftUI elements may not have explicit accessibility identifiers. Tests use text-based queries which may need adjustment if UI text changes.

2. **Async Operations**: Some operations (like API calls) are async. Tests include appropriate waits, but timing may need adjustment based on network conditions.

3. **Mock Mode**: Tests run in mock mode, so some edge cases that require specific API responses may need additional mocking.

## Maintenance

### When UI Changes
- Update element queries if text or structure changes
- Verify accessibility identifiers are still correct
- Update test expectations if behavior changes

### When Adding Features
- Add corresponding UI tests for new user flows
- Update helper methods if new common patterns emerge
- Document any new test utilities

## CI Integration

These tests are integrated into the CI pipeline (see `.github/workflows/ios.yml`). They run automatically on:
- Pull requests
- Pushes to main/develop branches

## Troubleshooting

### Tests Failing Intermittently
- Increase timeout values for slow operations
- Add explicit waits for async operations
- Check if elements are actually visible/hittable

### Element Not Found
- Verify element exists in the UI
- Check if element has proper accessibility label
- Use Xcode's UI test recorder to find correct queries

### Tests Timing Out
- Check if app is actually launching
- Verify mock API mode is working
- Check for blocking operations in app startup

