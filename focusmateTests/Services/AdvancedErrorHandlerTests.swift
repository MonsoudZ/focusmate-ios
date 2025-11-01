import XCTest
@testable import focusmate

@MainActor
final class AdvancedErrorHandlerTests: XCTestCase {
  var handler: AdvancedErrorHandler!

  override func setUpWithError() throws {
    try super.setUpWithError()
    handler = AdvancedErrorHandler.shared
  }

  override func tearDownWithError() throws {
    // Clear retry state after each test
    handler.retryCount.removeAll()
    handler.lastRetryTime.removeAll()
    handler = nil
    try super.tearDownWithError()
  }

  // MARK: - FocusmateError Tests

  func testFocusmateErrorCodes() {
    XCTAssertEqual(FocusmateError.network(URLError(.badServerResponse)).code, "NETWORK_ERROR")
    XCTAssertEqual(FocusmateError.unauthorized(nil).code, "UNAUTHORIZED")
    XCTAssertEqual(FocusmateError.badRequest("Bad", nil).code, "BAD_REQUEST")
    XCTAssertEqual(FocusmateError.notFound(nil).code, "NOT_FOUND")
    XCTAssertEqual(FocusmateError.serverError(500, nil, nil).code, "SERVER_ERROR_500")
    XCTAssertEqual(FocusmateError.decoding(nil).code, "DECODING_ERROR")
    XCTAssertEqual(FocusmateError.validation([:], nil).code, "VALIDATION_ERROR")
    XCTAssertEqual(FocusmateError.rateLimited(60, nil).code, "RATE_LIMITED")
    XCTAssertEqual(FocusmateError.timeout.code, "TIMEOUT")
    XCTAssertEqual(FocusmateError.noInternetConnection.code, "NO_INTERNET")
    XCTAssertEqual(FocusmateError.custom("CUSTOM_CODE", nil).code, "CUSTOM_CODE")
  }

  func testFocusmateErrorTitles() {
    XCTAssertEqual(FocusmateError.network(URLError(.badServerResponse)).title, "Connection Problem")
    XCTAssertEqual(FocusmateError.unauthorized(nil).title, "Sign In Required")
    XCTAssertEqual(FocusmateError.badRequest("Bad", nil).title, "Invalid Request")
    XCTAssertEqual(FocusmateError.notFound(nil).title, "Not Found")
    XCTAssertEqual(FocusmateError.serverError(500, nil, nil).title, "Server Error")
    XCTAssertEqual(FocusmateError.decoding(nil).title, "Data Error")
    XCTAssertEqual(FocusmateError.validation([:], nil).title, "Validation Error")
    XCTAssertEqual(FocusmateError.rateLimited(60, nil).title, "Too Many Requests")
    XCTAssertEqual(FocusmateError.timeout.title, "Timeout")
    XCTAssertEqual(FocusmateError.noInternetConnection.title, "No Connection")
    XCTAssertEqual(FocusmateError.custom("CODE", nil).title, "Error")
  }

  func testFocusmateErrorMessages() {
    // Test unauthorized with default message
    XCTAssertTrue(FocusmateError.unauthorized(nil).message.contains("session has expired"))

    // Test unauthorized with custom message
    XCTAssertEqual(FocusmateError.unauthorized("Custom message").message, "Custom message")

    // Test bad request with empty message
    XCTAssertTrue(FocusmateError.badRequest("", nil).message.contains("problem with your request"))

    // Test bad request with message
    XCTAssertEqual(FocusmateError.badRequest("Custom error", nil).message, "Custom error")

    // Test server error 500+
    XCTAssertTrue(FocusmateError.serverError(500, nil, nil).message.contains("servers are experiencing"))

    // Test server error with custom message
    XCTAssertEqual(FocusmateError.serverError(500, "Custom", nil).message, "Custom")

    // Test rate limited with seconds
    let rateLimitError = FocusmateError.rateLimited(30, nil)
    XCTAssertTrue(rateLimitError.message.contains("30 seconds"))

    // Test rate limited with minutes
    let rateLimitMinutes = FocusmateError.rateLimited(120, nil)
    XCTAssertTrue(rateLimitMinutes.message.contains("2 minutes"))

    // Test rate limited with custom message
    XCTAssertEqual(FocusmateError.rateLimited(60, "Custom").message, "Custom")

    // Test validation with custom message
    let validationError = FocusmateError.validation(["field": ["error1", "error2"]], "Custom")
    XCTAssertEqual(validationError.message, "Custom")

    // Test validation without custom message
    let validationDefault = FocusmateError.validation(["email": ["is invalid"]], nil)
    XCTAssertTrue(validationDefault.message.contains("is invalid"))
  }

  func testFocusmateErrorRetryability() {
    // Retryable errors
    XCTAssertTrue(FocusmateError.network(URLError(.badServerResponse)).isRetryable)
    XCTAssertTrue(FocusmateError.timeout.isRetryable)
    XCTAssertTrue(FocusmateError.rateLimited(60, nil).isRetryable)
    XCTAssertTrue(FocusmateError.serverError(500, nil, nil).isRetryable)

    // Non-retryable errors
    XCTAssertFalse(FocusmateError.unauthorized(nil).isRetryable)
    XCTAssertFalse(FocusmateError.badRequest("Bad", nil).isRetryable)
    XCTAssertFalse(FocusmateError.notFound(nil).isRetryable)
    XCTAssertFalse(FocusmateError.decoding(nil).isRetryable)
    XCTAssertFalse(FocusmateError.validation([:], nil).isRetryable)
    XCTAssertFalse(FocusmateError.noInternetConnection.isRetryable)
    XCTAssertFalse(FocusmateError.custom("CODE", nil).isRetryable)
  }

  func testFocusmateErrorRetryAfter() {
    let rateLimitError = FocusmateError.rateLimited(120, nil)
    XCTAssertEqual(rateLimitError.retryAfterSeconds, 120)

    // Non-rate-limited errors should return nil
    XCTAssertNil(FocusmateError.timeout.retryAfterSeconds)
    XCTAssertNil(FocusmateError.unauthorized(nil).retryAfterSeconds)
  }

  func testFocusmateErrorSuggestedActions() {
    XCTAssertNotNil(FocusmateError.network(URLError(.badServerResponse)).suggestedAction)
    XCTAssertNotNil(FocusmateError.timeout.suggestedAction)
    XCTAssertNotNil(FocusmateError.unauthorized(nil).suggestedAction)
    XCTAssertNotNil(FocusmateError.noInternetConnection.suggestedAction)
    XCTAssertNotNil(FocusmateError.serverError(500, nil, nil).suggestedAction)
    XCTAssertNotNil(FocusmateError.rateLimited(60, nil).suggestedAction)

    // Errors without suggested actions
    XCTAssertNil(FocusmateError.badRequest("Bad", nil).suggestedAction)
    XCTAssertNil(FocusmateError.notFound(nil).suggestedAction)
  }

  // MARK: - Error Handling Tests

  func testHandleAPIError() {
    let apiError = APIError.unauthorized
    let processed = handler.handle(apiError, context: "test")

    XCTAssertEqual(processed.code, "UNAUTHORIZED")
  }

  func testHandleURLError() {
    let urlError = URLError(.notConnectedToInternet)
    let processed = handler.handle(urlError, context: "test")

    XCTAssertEqual(processed.code, "NO_INTERNET")
  }

  func testHandleTimeoutError() {
    let urlError = URLError(.timedOut)
    let processed = handler.handle(urlError, context: "test")

    XCTAssertEqual(processed.code, "TIMEOUT")
  }

  func testHandleNetworkError() {
    let urlError = URLError(.cannotConnectToHost)
    let processed = handler.handle(urlError, context: "test")

    XCTAssertEqual(processed.code, "NETWORK_ERROR")
  }

  // MARK: - Retry Logic Tests

  func testShouldRetryWithRetryableError() {
    let error = FocusmateError.timeout
    XCTAssertTrue(handler.shouldRetry(error: error, context: "test"))
  }

  func testShouldNotRetryWithNonRetryableError() {
    let error = FocusmateError.unauthorized(nil)
    XCTAssertFalse(handler.shouldRetry(error: error, context: "test"))
  }

  func testShouldNotRetryAfterMaxRetries() {
    let error = FocusmateError.timeout
    let context = "maxRetryTest"

    // First 3 retries should succeed
    XCTAssertTrue(handler.shouldRetry(error: error, context: context))
    handler.recordRetryAttempt(context: context, error: error)

    XCTAssertTrue(handler.shouldRetry(error: error, context: context))
    handler.recordRetryAttempt(context: context, error: error)

    XCTAssertTrue(handler.shouldRetry(error: error, context: context))
    handler.recordRetryAttempt(context: context, error: error)

    // 4th retry should fail (max is 3)
    XCTAssertFalse(handler.shouldRetry(error: error, context: context))
  }

  func testRecordRetryAttempt() {
    let error = FocusmateError.timeout
    let context = "recordTest"

    handler.recordRetryAttempt(context: context, error: error)

    let retryKey = "\(context)_\(error.code)"
    XCTAssertEqual(handler.retryCount[retryKey], 1)
    XCTAssertNotNil(handler.lastRetryTime[retryKey])
  }

  func testResetRetryCount() {
    let error = FocusmateError.timeout
    let context = "resetTest"

    handler.recordRetryAttempt(context: context, error: error)
    XCTAssertEqual(handler.retryCount["\(context)_\(error.code)"], 1)

    handler.resetRetryCount(context: context)
    XCTAssertNil(handler.retryCount["\(context)_\(error.code)"])
    XCTAssertNil(handler.lastRetryTime["\(context)_\(error.code)"])
  }

  func testBackoffDelayCalculation() {
    let error = FocusmateError.timeout
    let context = "backoffTest"

    // First retry: 1 second
    handler.recordRetryAttempt(context: context, error: error)
    // Second retry: 2 seconds
    handler.recordRetryAttempt(context: context, error: error)
    // Third retry: 4 seconds
    handler.recordRetryAttempt(context: context, error: error)

    // Verify retry count increased
    XCTAssertEqual(handler.retryCount["\(context)_\(error.code)"], 3)
  }

  // MARK: - Re-authentication Tests

  func testHandleUnauthorized() async {
    let result = await handler.handleUnauthorized()
    XCTAssertTrue(result)
  }

  func testHandleUnauthorizedWhileAlreadyReauthenticating() async {
    // Start first re-auth
    handler.isReauthenticating = true

    let result = await handler.handleUnauthorized()
    XCTAssertFalse(result)

    handler.isReauthenticating = false
  }

  // MARK: - Retry with Backoff Tests

  func testRetryWithBackoffSuccess() async throws {
    var attemptCount = 0

    let result = try await handler.retryWithBackoff(
      context: "successTest",
      error: FocusmateError.timeout
    ) {
      attemptCount += 1
      return "success"
    }

    XCTAssertEqual(result, "success")
    XCTAssertEqual(attemptCount, 1)
  }

  func testRetryWithBackoffNonRetryableError() async {
    let error = FocusmateError.unauthorized(nil)

    do {
      _ = try await handler.retryWithBackoff(
        context: "nonRetryableTest",
        error: error
      ) {
        return "success"
      }
      XCTFail("Should have thrown error")
    } catch let focusmateError as FocusmateError {
      XCTAssertEqual(focusmateError.code, "UNAUTHORIZED")
    } catch {
      XCTFail("Wrong error type thrown")
    }
  }

  // MARK: - HTTP Status Processing Tests

  func testProcessAPIErrorBadRequest() {
    let apiError = APIError.badStatus(400, "Bad request", nil)
    let processed = handler.handle(apiError, context: "test")

    XCTAssertEqual(processed.code, "BAD_REQUEST")
  }

  func testProcessAPIErrorNotFound() {
    let apiError = APIError.badStatus(404, "Not found", nil)
    let processed = handler.handle(apiError, context: "test")

    XCTAssertEqual(processed.code, "NOT_FOUND")
  }

  func testProcessAPIErrorValidation() {
    let details: [String: Any] = ["errors": ["email": ["is invalid"], "password": ["is too short"]]]
    let apiError = APIError.badStatus(422, "Validation failed", details)
    let processed = handler.handle(apiError, context: "test")

    XCTAssertEqual(processed.code, "VALIDATION_ERROR")

    // Check that validation error message contains field errors
    if case .validation(let errors, _) = processed {
      XCTAssertEqual(errors["email"], ["is invalid"])
      XCTAssertEqual(errors["password"], ["is too short"])
    } else {
      XCTFail("Expected validation error")
    }
  }

  func testProcessAPIErrorRateLimited() {
    let apiError = APIError.rateLimited(120)
    let processed = handler.handle(apiError, context: "test")

    XCTAssertEqual(processed.code, "RATE_LIMITED")
    XCTAssertEqual(processed.retryAfterSeconds, 120)
  }

  func testProcessAPIErrorServerError() {
    let apiError = APIError.serverError(500, "Internal error", nil)
    let processed = handler.handle(apiError, context: "test")

    XCTAssertEqual(processed.code, "SERVER_ERROR_500")
    XCTAssertTrue(processed.isRetryable)
  }
}
