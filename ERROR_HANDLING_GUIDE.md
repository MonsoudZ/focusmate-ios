# Advanced Error Handling System

This document describes the comprehensive error handling system with structured error codes, 401 re-authentication, and 429 backoff handling.

## Overview

The error handling system provides:
- **Structured Error Codes**: Consistent error identification and messaging
- **401 Re-authentication**: Automatic handling of unauthorized access
- **429 Rate Limiting**: Exponential backoff for rate-limited requests
- **Retry Logic**: Intelligent retry mechanisms with backoff
- **User-Friendly Alerts**: Contextual error messages and actions

## Architecture

### Core Components

1. **AdvancedErrorHandler.swift** - Main error processing and retry logic
2. **APIError.swift** - Enhanced API error types with structured responses
3. **ErrorHandler.swift** - Backward-compatible wrapper
4. **APIClient.swift** - Enhanced with error response parsing

### Error Types

#### FocusmateError
```swift
enum FocusmateError: LocalizedError, Equatable {
    case network(Error)
    case unauthorized(String?)
    case badRequest(String, String?)
    case notFound(String?)
    case serverError(Int, String?, String?)
    case decoding(String?)
    case validation([String: [String]], String?)
    case rateLimited(Int, String?)
    case timeout
    case noInternetConnection
    case custom(String, String?)
}
```

#### APIError
```swift
enum APIError: Error {
    case badURL
    case badStatus(Int, String?, [String: Any]?)
    case decoding
    case unauthorized
    case network(Error)
    case rateLimited(Int)
    case serverError(Int, String?, [String: Any]?)
    case validation([String: [String]])
    case timeout
    case noInternetConnection
}
```

## Structured Error Response

### ErrorResponse Model
```swift
struct ErrorResponse: Codable {
    let code: String
    let message: String
    let details: [String: Any]?
    let timestamp: String?
    let requestId: String?
}
```

### Expected API Error Format
```json
{
  "code": "VALIDATION_ERROR",
  "message": "Validation failed",
  "details": {
    "field_errors": {
      "email": ["is invalid"],
      "password": ["is too short"]
    }
  },
  "timestamp": "2024-01-15T10:30:00Z",
  "request_id": "req_123456"
}
```

## Error Handling Features

### 1. Structured Error Processing

#### Error Code Mapping
- **NETWORK_ERROR**: Network connectivity issues
- **UNAUTHORIZED**: Authentication required
- **BAD_REQUEST**: Invalid request parameters
- **NOT_FOUND**: Resource not found
- **SERVER_ERROR_XXX**: Server-side errors with status codes
- **DECODING_ERROR**: Response parsing failures
- **VALIDATION_ERROR**: Input validation failures
- **RATE_LIMITED**: Rate limit exceeded
- **TIMEOUT**: Request timeout
- **NO_INTERNET**: No internet connection

#### Error Message Processing
```swift
let error = errorHandler.handle(apiError, context: "user_login")
print("Code: \(error.code)")
print("Message: \(error.message)")
print("Retryable: \(error.isRetryable)")
```

### 2. 401 Re-authentication Handling

#### Automatic Re-authentication
```swift
// When 401 error occurs
let reauthResult = await errorHandler.handleUnauthorized()
if reauthResult {
    // User was successfully re-authenticated
    // Retry the original operation
}
```

#### Re-authentication Flow
1. **Detect 401**: API returns unauthorized status
2. **Clear Credentials**: Remove stored JWT and user data
3. **Navigate to Sign-in**: Redirect user to authentication
4. **Wait for Re-auth**: User completes authentication
5. **Retry Operation**: Original request is retried

### 3. 429 Rate Limiting with Backoff

#### Exponential Backoff Algorithm
```swift
private func calculateBackoffDelay(retryCount: Int) -> TimeInterval {
    let exponentialDelay = baseBackoffDelay * pow(2.0, Double(retryCount))
    return min(exponentialDelay, maxBackoffDelay)
}
```

#### Backoff Configuration
- **Base Delay**: 1.0 seconds
- **Max Delay**: 60.0 seconds
- **Max Retries**: 3 attempts
- **Retry-After Header**: Respects server-specified delays

#### Rate Limit Handling
```swift
// Automatic retry with backoff
let result = try await errorHandler.handleWithRetry(context: "api_call") {
    try await apiClient.request("GET", "endpoint")
}
```

### 4. Retry Logic

#### Retryable Errors
- Network connectivity issues
- Timeout errors
- Rate limiting (429)
- Server errors (5xx)

#### Non-Retryable Errors
- Authentication failures (401)
- Bad requests (400)
- Not found (404)
- Validation errors (422)
- Decoding errors

#### Retry Tracking
```swift
// Per-context retry tracking
let retryKey = "\(context)_\(error.code)"
let currentRetries = retryCount[retryKey] ?? 0
let lastRetryTime = lastRetryTime[retryKey]
```

## Usage Examples

### Basic Error Handling
```swift
do {
    let result = try await apiClient.request("GET", "endpoint")
    // Handle success
} catch {
    let processedError = errorHandler.handle(error, context: "fetch_data")
    // Show user-friendly error message
    showAlert(processedError)
}
```

### Retry with Backoff
```swift
let result = try await errorHandler.handleWithRetry(context: "sync_data") {
    try await syncService.syncAll()
}
```

### 401 Handling
```swift
if error.code == "UNAUTHORIZED" {
    let reauthResult = await errorHandler.handleUnauthorized()
    if reauthResult {
        // Retry the operation
        try await retryOperation()
    }
}
```

### Rate Limit Handling
```swift
if error.code == "RATE_LIMITED" {
    let retryAfter = error.retryAfterSeconds ?? 60
    showMessage("Rate limit exceeded. Retry after \(retryAfter) seconds.")
}
```

## User Interface Integration

### Error Alerts
```swift
func showAlert(for error: FocusmateError) -> Alert {
    if error.code == "UNAUTHORIZED" {
        return Alert(
            title: Text("Session Expired"),
            message: Text(error.message),
            primaryButton: .default(Text("Sign In")) {
                Task { await handleUnauthorized() }
            },
            secondaryButton: .cancel(Text("Cancel"))
        )
    }
    // ... other alert types
}
```

### Contextual Error Messages
- **Network Issues**: "Check your internet connection"
- **Authentication**: "Please sign in again"
- **Rate Limiting**: "Too many requests. Please wait X seconds"
- **Server Errors**: "Something went wrong. Please try again"

## Testing

### ErrorHandlingTestView
Comprehensive testing interface for:
1. **Structured Errors**: Test error code and message processing
2. **401 Re-authentication**: Test unauthorized handling
3. **429 Rate Limiting**: Test rate limit and backoff
4. **Retry Logic**: Test retry mechanisms
5. **Error Alerts**: Test user interface alerts

### Test Scenarios
```swift
// Test different error types
let errors: [Error] = [
    APIError.unauthorized,
    APIError.rateLimited(60),
    APIError.serverError(500, "Internal error", nil),
    APIError.network(URLError(.notConnectedToInternet))
]

for error in errors {
    let processed = errorHandler.handle(error, context: "test")
    print("\(processed.code): \(processed.message)")
}
```

## Configuration

### Error Handler Settings
```swift
private let maxRetries = 3
private let baseBackoffDelay: TimeInterval = 1.0
private let maxBackoffDelay: TimeInterval = 60.0
```

### API Client Configuration
```swift
// Enhanced error parsing
let errorResponse = parseErrorResponse(data: data, statusCode: statusCode)
let retryAfter = extractRetryAfter(from: headers)
```

## Benefits

1. **Consistent Error Handling**: Standardized error codes and messages
2. **Automatic Recovery**: Retry logic with intelligent backoff
3. **User Experience**: Contextual error messages and actions
4. **Developer Experience**: Clear error identification and debugging
5. **Resilience**: Handles network issues and rate limiting gracefully

## Future Enhancements

1. **Error Analytics**: Track error patterns and frequencies
2. **Custom Retry Policies**: Per-endpoint retry configurations
3. **Error Categorization**: Group similar errors for better handling
4. **Offline Error Queuing**: Queue operations when offline
5. **Error Recovery Suggestions**: Provide actionable recovery steps

## Troubleshooting

### Common Issues

1. **Infinite Retry Loops**: Check retry limits and backoff delays
2. **Memory Leaks**: Ensure proper cleanup of retry tracking
3. **UI Blocking**: Use async/await for error handling
4. **Error Message Clarity**: Ensure messages are user-friendly

### Debug Information

The system provides extensive logging:
```
🔍 AdvancedErrorHandler: Processing error in context 'user_login'
🔄 AdvancedErrorHandler: Recorded retry attempt 1 for user_login_NETWORK_ERROR
⏰ AdvancedErrorHandler: Waiting 2.0 seconds before retry for user_login
```

This comprehensive error handling system provides robust error management with automatic recovery, user-friendly messaging, and intelligent retry mechanisms.
