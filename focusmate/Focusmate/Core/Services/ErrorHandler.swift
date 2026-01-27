import Foundation
import SwiftUI

// MARK: - Legacy ErrorHandler (Backward Compatibility)

final class ErrorHandler: @unchecked Sendable {
  static let shared = ErrorHandler()
  private let advancedHandler = AdvancedErrorHandler.shared
  private let sentryService = SentryService.shared

  private init() {}

  func handle(_ error: Error, context: String = "") -> FocusmateError {
    let focusmateError = self.advancedHandler.handle(error, context: context)

    // Send error to Sentry
    var sentryContext: [String: Any] = [:]
    if !context.isEmpty {
      sentryContext["context"] = context
    }
    sentryContext["error_code"] = focusmateError.code
    sentryContext["is_retryable"] = focusmateError.isRetryable

    sentryService.captureError(error, context: sentryContext)

    return focusmateError
  }

  @MainActor func showAlert(for error: FocusmateError) -> Alert {
    return self.advancedHandler.showAlert(for: error)
  }

  // MARK: - Enhanced Methods

  func handleWithRetry<T>(
    context: String,
    operation: @escaping () async throws -> T
  ) async throws -> T {
    do {
      return try await operation()
    } catch {
      let processedError = self.handle(error, context: context)

      if processedError.isRetryable {
        return try await self.advancedHandler.retryWithBackoff(
          context: context,
          error: processedError,
          operation: operation
        )
      }

      throw processedError
    }
  }

  func handleUnauthorized() async -> Bool {
    return await self.advancedHandler.handleUnauthorized()
  }

  @MainActor func shouldRetry(error: FocusmateError, context: String) -> Bool {
    return self.advancedHandler.shouldRetry(error: error, context: context)
  }
}
