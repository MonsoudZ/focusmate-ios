import Combine
import Foundation
import SwiftUI

/// Central error handler that coordinates error mapping, retry logic, and user feedback.
/// Uses ErrorMapper for conversion and RetryCoordinator for retry logic.
@MainActor
final class AdvancedErrorHandler: ObservableObject {
    static let shared = AdvancedErrorHandler()

    @Published var isReauthenticating = false

    private let retryCoordinator: RetryCoordinator

    private init(retryCoordinator: RetryCoordinator = .shared) {
        self.retryCoordinator = retryCoordinator
    }

    // MARK: - Error Processing

    /// Maps any error to a FocusmateError with logging.
    ///
    /// ## Thread Safety
    /// This method is `nonisolated` to allow calling from any context (background
    /// network callbacks, etc.) without requiring MainActor dispatch at call site.
    ///
    /// Previous implementation spawned a Task to log on MainActor, but that task
    /// executed asynchronously after the function returned, causing:
    /// - Log messages appearing out of order (confusing during debugging)
    /// - Potential future data races if Logger accessed mutable state
    ///
    /// ## Current Approach
    /// ErrorMapper.map() is pure (no side effects) and thread-safe.
    /// Logging is removed from this hot path; callers can log if needed.
    nonisolated func handle(_ error: Error, context: String = "") -> FocusmateError {
        return ErrorMapper.map(error)
    }

    // MARK: - Re-authentication

    /// Called by AuthStore before it clears credentials and sends signedOut event.
    /// This method manages the re-authentication flag to prevent duplicate handling.
    /// Actual credential clearing is done by AuthStore.clearLocalSession().
    /// Navigation reset is handled by AppRouter listening to AuthEventBus.signedOut.
    func handleUnauthorized() async -> Bool {
        guard !isReauthenticating else {
            Logger.debug("AdvancedErrorHandler: Already re-authenticating, skipping", category: .general)
            return false
        }

        isReauthenticating = true
        defer { isReauthenticating = false }

        Logger.debug("AdvancedErrorHandler: Unauthorized handled, AuthStore will clear session", category: .general)
        return true
    }

    // MARK: - Retry Logic (delegated to RetryCoordinator)

    func shouldRetry(error: FocusmateError, context: String) -> Bool {
        retryCoordinator.shouldRetry(error: error, context: context)
    }

    func retryWithBackoff<T>(
        context: String,
        error: FocusmateError,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await retryCoordinator.retryWithBackoff(context: context, error: error, operation: operation)
    }

    // MARK: - Alert Generation

    func showAlert(for error: FocusmateError) -> Alert {
        if error.code == "UNAUTHORIZED" {
            return Alert(
                title: Text("Error"),
                message: Text(error.message),
                primaryButton: .default(Text("Sign In")) {
                    Task {
                        await self.handleUnauthorized()
                    }
                },
                secondaryButton: .cancel(Text("Cancel"))
            )
        } else if error.code == "RATE_LIMITED" {
            let retryAfter = error.retryAfterSeconds ?? 60
            return Alert(
                title: Text("Error"),
                message: Text("\(error.message)\n\nPlease wait \(retryAfter) seconds before trying again."),
                dismissButton: .default(Text("OK"))
            )
        } else {
            return Alert(
                title: Text("Error"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}
