import Foundation

/// Central error handler: maps errors, reports to Sentry, manages re-auth flag.
///
/// Consolidates the former ErrorHandler + AdvancedErrorHandler into a single class.
/// Dead code removed: handleWithRetry(), showAlert(), shouldRetry(), RetryCoordinator.
/// InternalNetworking owns its own 401-retry logic; no external retry coordinator needed.
@Observable
@MainActor
final class ErrorHandler {
  static let shared = ErrorHandler()

  var isReauthenticating = false

  private init() {}

  // MARK: - Error Processing

  /// Maps any error to a FocusmateError and reports to Sentry.
  ///
  /// `nonisolated` so callers on any thread can use it without MainActor dispatch.
  /// ErrorMapper.map() is pure and thread-safe. Sentry reporting is fire-and-forget
  /// via an unstructured Task since SentryService is @MainActor-isolated.
  nonisolated func handle(_ error: Error, context: String = "") -> FocusmateError {
    let focusmateError = ErrorMapper.map(error)

    var sentryContext: [String: Any] = [:]
    if !context.isEmpty {
      sentryContext["context"] = context
    }
    sentryContext["error_code"] = focusmateError.code
    sentryContext["is_retryable"] = focusmateError.isRetryable

    Task { @MainActor in
      SentryService.shared.captureError(error, context: sentryContext)
    }

    return focusmateError
  }

  // MARK: - Re-authentication

  /// Called by AuthStore before it clears credentials and sends signedOut event.
  /// Manages the re-authentication flag to prevent duplicate handling.
  /// Actual credential clearing is done by AuthStore.clearLocalSession().
  /// Navigation reset is handled by AppRouter listening to AuthEventBus.signedOut.
  func handleUnauthorized() async -> Bool {
    guard !self.isReauthenticating else {
      Logger.debug("ErrorHandler: Already re-authenticating, skipping", category: .general)
      return false
    }

    self.isReauthenticating = true
    defer { isReauthenticating = false }

    Logger.debug("ErrorHandler: Unauthorized handled, AuthStore will clear session", category: .general)
    return true
  }
}
