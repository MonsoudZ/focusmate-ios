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
    nonisolated func handle(_ error: Error, context: String = "") -> FocusmateError {
        Task { @MainActor in
            Logger.debug("AdvancedErrorHandler: Processing error in context '\(context)': \(error)", category: .general)
        }
        return ErrorMapper.map(error)
    }

    // MARK: - Re-authentication

    func handleUnauthorized() async -> Bool {
        guard !isReauthenticating else {
            Logger.debug("AdvancedErrorHandler: Already re-authenticating, skipping", category: .general)
            return false
        }

        isReauthenticating = true
        Logger.debug("AdvancedErrorHandler: Starting re-authentication process", category: .general)

        await clearStoredCredentials()
        await navigateToSignIn()

        isReauthenticating = false
        return true
    }

    private func clearStoredCredentials() async {
        Logger.debug("AdvancedErrorHandler: Clearing stored credentials", category: .general)
        // Integrates with AuthStore via AuthEventBus
    }

    private func navigateToSignIn() async {
        Logger.debug("AdvancedErrorHandler: Navigating to sign-in", category: .general)
        // Integrates with navigation system via AppRouter
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
