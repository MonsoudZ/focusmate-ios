# Testing Guide

## Overview

This document provides guidelines for testing the Focusmate iOS application. The app uses XCTest framework for unit, integration, and UI tests.

## Test Structure

```
focusmateTests/
├── Mocks/                    # Mock objects and test doubles
│   ├── MockAPIClient.swift   # Mock API client
│   └── MockData.swift         # Test fixtures and sample data
├── Services/                  # Service layer tests
│   └── ItemServiceTests.swift
├── ViewModels/                # ViewModel tests
│   └── ItemViewModelTests.swift
├── Integration/               # Integration tests
│   └── APIClientE2ETests.swift
└── APISmokeTest.swift         # Smoke tests

focusmateUITests/              # UI tests
└── focusmateUITests.swift
```

## Running Tests

### Command Line

```bash
# Run all tests
xcodebuild test -project focusmate.xcodeproj -scheme focusmate -destination 'platform=iOS Simulator,name=iPhone 17'

# Run specific test class
xcodebuild test -project focusmate.xcodeproj -scheme focusmate -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:focusmateTests/ItemServiceTests

# Run with coverage
xcodebuild test -project focusmate.xcodeproj -scheme focusmate -destination 'platform=iOS Simulator,name=iPhone 17' -enableCodeCoverage YES
```

### Xcode

1. Open `focusmate.xcodeproj` in Xcode
2. Press `⌘ + U` to run all tests
3. Or navigate to Test Navigator (⌘ + 6) and run individual tests

## Test Categories

### Unit Tests

Test individual components in isolation using mocks and stubs.

**Examples:**
- `ItemServiceTests` - Tests ItemService methods with mocked networking
- `ItemViewModelTests` - Tests view model logic and state management

**Guidelines:**
- Use mocks to isolate the system under test
- Test both success and failure scenarios
- Verify state changes and side effects
- Keep tests fast (< 0.1s per test)

### Integration Tests

Test interactions between multiple components.

**Examples:**
- `APIClientE2ETests` - Tests actual API communication (requires server)

**Guidelines:**
- Test real interactions between components
- May use test database or sandbox environment
- Can be slower than unit tests
- Should be idempotent (repeatable)

### UI Tests

Test user interface and user flows.

**Examples:**
- Login flow
- Create and complete task flow
- Navigation between screens

**Guidelines:**
- Test critical user paths
- Use accessibility identifiers
- Keep UI tests focused and maintainable
- Run on CI/CD pipeline

## Writing Tests

### Test Structure (AAA Pattern)

```swift
func testExampleFeature() async throws {
    // Arrange - Set up test data and mocks
    let mockData = MockData.mockItem
    mockNetworking.mockResponses["endpoint"] = mockData

    // Act - Execute the code under test
    let result = try await service.fetchData()

    // Assert - Verify the results
    XCTAssertEqual(result.id, mockData.id)
    XCTAssertEqual(mockNetworking.requestCallCount, 1)
}
```

### Async Testing

```swift
func testAsyncOperation() async throws {
    // When testing async code, use await
    await viewModel.loadItems(listId: 1)

    // Then verify state
    XCTAssertFalse(viewModel.isLoading)
}
```

### Error Testing

```swift
func testErrorHandling() async {
    // Given
    mockNetworking.shouldFail = true
    mockNetworking.mockError = APIError.unauthorized

    // When/Then
    do {
        _ = try await service.fetchData()
        XCTFail("Expected error to be thrown")
    } catch {
        XCTAssertTrue(error is APIError)
    }
}
```

### Performance Testing

```swift
func testPerformance() {
    measure {
        // Code to measure
        Task {
            await viewModel.loadItems(listId: 1)
        }
    }
}
```

## Mock Objects

### MockNetworking

Mocks the networking layer for testing without real API calls.

```swift
let mockNetworking = MockNetworking()

// Set mock response
mockNetworking.mockResponses["lists/1/tasks"] = MockData.mockItemsResponse

// Simulate failure
mockNetworking.shouldFail = true
mockNetworking.mockError = APIError.unauthorized

// Add delay for testing loading states
mockNetworking.mockDelay = 0.5
```

### MockData

Provides test fixtures for common data types.

```swift
// Use predefined mock data
let item = MockData.mockItem
let items = MockData.mockItems
let user = MockData.mockUser
```

## Best Practices

### DO

✅ Write tests for new features
✅ Test edge cases and error scenarios
✅ Use descriptive test names (e.g., `testCreateItemWithEmptyNameReturnsError`)
✅ Keep tests independent and isolated
✅ Use setUp/tearDown for common initialization
✅ Mock external dependencies
✅ Test both success and failure paths
✅ Verify error messages and error types
✅ Run tests before committing

### DON'T

❌ Test implementation details
❌ Make tests dependent on each other
❌ Use real API calls in unit tests
❌ Ignore flaky tests
❌ Write overly complex test logic
❌ Test framework code (UIKit, SwiftUI, etc.)
❌ Commit commented-out tests

## Test Coverage Goals

- **Services**: 80%+ coverage
- **ViewModels**: 75%+ coverage
- **Critical User Flows**: 100% UI test coverage
- **Overall**: 70%+ code coverage

## Continuous Integration

Tests should run automatically on:
- Every pull request
- Before merging to main
- Nightly builds

## Debugging Tests

### Common Issues

1. **Tests fail locally but pass on CI**
   - Check for hardcoded paths or dates
   - Verify timezone handling
   - Check async race conditions

2. **Flaky tests**
   - Add proper waits for async operations
   - Use expectation pattern for callbacks
   - Avoid testing timing-dependent behavior

3. **Slow tests**
   - Profile with Instruments
   - Check for unnecessary delays
   - Optimize database queries

### Debugging Commands

```bash
# Run specific test
xcodebuild test -only-testing:focusmateTests/ItemServiceTests/testFetchItemsSuccess

# Enable verbose logging
xcodebuild test -verbose

# Run with sanitizers
xcodebuild test -enableThreadSanitizer YES
xcodebuild test -enableAddressSanitizer YES
```

## Resources

- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [Testing in Swift](https://www.swift.org/documentation/testing/)
- [WWDC Testing Videos](https://developer.apple.com/videos/frameworks/testing)

## Contributing

When adding new features:
1. Write tests first (TDD) or alongside the feature
2. Ensure all tests pass
3. Update this guide if adding new test patterns
4. Request code review including test review
