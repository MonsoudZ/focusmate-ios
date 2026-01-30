import Foundation

/// Manages retry logic with exponential backoff for failed operations.
/// Tracks retry counts per context to prevent infinite retry loops.
@MainActor
final class RetryCoordinator {
    static let shared = RetryCoordinator()

    // MARK: - Configuration

    private let maxRetries: Int
    private let baseBackoffDelay: TimeInterval
    private let maxBackoffDelay: TimeInterval

    // MARK: - State

    private var retryCount: [String: Int] = [:]
    private var lastRetryTime: [String: Date] = [:]

    // MARK: - Init

    init(
        maxRetries: Int = AppConfiguration.Retry.maxAttempts,
        baseBackoffDelay: TimeInterval = AppConfiguration.Retry.baseBackoffSeconds,
        maxBackoffDelay: TimeInterval = AppConfiguration.Retry.maxBackoffSeconds
    ) {
        self.maxRetries = maxRetries
        self.baseBackoffDelay = baseBackoffDelay
        self.maxBackoffDelay = maxBackoffDelay
    }

    // MARK: - Retry Decision

    /// Determines if an operation should be retried based on error type and retry history.
    func shouldRetry(error: FocusmateError, context: String) -> Bool {
        guard error.isRetryable else { return false }

        let retryKey = makeRetryKey(context: context, error: error)
        let currentRetries = retryCount[retryKey] ?? 0

        if currentRetries >= maxRetries {
            Logger.debug("RetryCoordinator: Max retries exceeded for \(retryKey)", category: .general)
            return false
        }

        // Check if enough time has passed since last retry
        if let lastRetry = lastRetryTime[retryKey] {
            let timeSinceLastRetry = Date().timeIntervalSince(lastRetry)
            let requiredDelay = calculateBackoffDelay(retryCount: currentRetries)

            if timeSinceLastRetry < requiredDelay {
                Logger.debug("RetryCoordinator: Backoff not elapsed for \(retryKey)", category: .general)
                return false
            }
        }

        return true
    }

    // MARK: - Retry Tracking

    /// Records a retry attempt for the given context and error.
    func recordRetryAttempt(context: String, error: FocusmateError) {
        let retryKey = makeRetryKey(context: context, error: error)
        retryCount[retryKey, default: 0] += 1
        lastRetryTime[retryKey] = Date()

        Logger.debug("RetryCoordinator: Attempt \(retryCount[retryKey] ?? 0) for \(retryKey)", category: .general)
    }

    /// Resets retry tracking for a context after successful operation.
    func resetRetryCount(context: String) {
        let keysToRemove = retryCount.keys.filter { $0.hasPrefix(context) }
        for key in keysToRemove {
            retryCount.removeValue(forKey: key)
            lastRetryTime.removeValue(forKey: key)
        }
        Logger.debug("RetryCoordinator: Reset retry count for context: \(context)", category: .general)
    }

    // MARK: - Retry Execution

    /// Executes an operation with automatic retry and exponential backoff.
    func retryWithBackoff<T>(
        context: String,
        error: FocusmateError,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        guard shouldRetry(error: error, context: context) else {
            throw error
        }

        recordRetryAttempt(context: context, error: error)

        let retryKey = makeRetryKey(context: context, error: error)
        let delay = calculateBackoffDelay(retryCount: retryCount[retryKey] ?? 0)
        Logger.debug("RetryCoordinator: Waiting \(delay)s before retry for \(context)", category: .general)

        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        do {
            let result = try await operation()
            resetRetryCount(context: context)
            return result
        } catch {
            let newError = ErrorMapper.map(error)
            if shouldRetry(error: newError, context: context) {
                return try await retryWithBackoff(context: context, error: newError, operation: operation)
            }
            throw newError
        }
    }

    // MARK: - Helpers

    private func makeRetryKey(context: String, error: FocusmateError) -> String {
        "\(context)_\(error.code)"
    }

    private func calculateBackoffDelay(retryCount: Int) -> TimeInterval {
        let exponentialDelay = baseBackoffDelay * pow(2.0, Double(retryCount))
        return min(exponentialDelay, maxBackoffDelay)
    }
}
