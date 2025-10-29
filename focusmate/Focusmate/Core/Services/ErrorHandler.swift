import Foundation
import SwiftUI

// MARK: - Legacy ErrorHandler (Backward Compatibility)

final class ErrorHandler {
  static let shared = ErrorHandler()
  private let advancedHandler = AdvancedErrorHandler.shared

  private init() {}

  func handle(_ error: Error, context: String = "") -> FocusmateError {
    return self.advancedHandler.handle(error, context: context)
  }

  func showAlert(for error: FocusmateError) -> Alert {
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

  func shouldRetry(error: FocusmateError, context: String) -> Bool {
    return self.advancedHandler.shouldRetry(error: error, context: context)
  }
}
