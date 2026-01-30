import Foundation

/// Centralized configuration values for the app.
/// Grouping magic numbers here makes them discoverable, documented, and easy to adjust.
enum AppConfiguration {

    // MARK: - Escalation & App Blocking

    enum Escalation {
        /// How long users have to complete overdue tasks before app blocking starts.
        static let gracePeriodMinutes: Int = 120

        /// When to show "time remaining" warning notification before blocking.
        static let warningMinutes: Int = 30

        /// How often to check grace period status (handles app restart scenarios).
        static let statusCheckIntervalSeconds: TimeInterval = 60
    }

    // MARK: - Network & API

    enum Network {
        /// Timeout for individual HTTP requests.
        static let requestTimeoutSeconds: TimeInterval = 30

        /// Timeout for resource loading (downloads, large responses).
        static let resourceTimeoutSeconds: TimeInterval = 60
    }

    // MARK: - Retry Logic

    enum Retry {
        /// Maximum number of retry attempts for failed requests.
        static let maxAttempts: Int = 3

        /// Initial delay before first retry (doubles each attempt).
        static let baseBackoffSeconds: TimeInterval = 1.0

        /// Maximum delay between retries (caps exponential growth).
        static let maxBackoffSeconds: TimeInterval = 60.0
    }

    // MARK: - Cache TTL (Time-To-Live)

    enum Cache {
        /// How long to cache the lists response.
        static let listsTTLSeconds: TimeInterval = 60

        /// How long to cache today's tasks (short — data changes frequently).
        static let todayTTLSeconds: TimeInterval = 10

        /// How long to cache calendar events lookup.
        static let calendarEventsTTLSeconds: TimeInterval = 2
    }
}
