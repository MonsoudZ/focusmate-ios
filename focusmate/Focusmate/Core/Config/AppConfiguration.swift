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

  // MARK: - Auth & Token Refresh

  enum Auth {
    /// How many seconds before JWT expiry to trigger a proactive refresh.
    /// At 300s (5 min), any request made within 5 minutes of token expiry
    /// refreshes first, avoiding the 401 → refresh → retry round trip.
    /// Tradeoff: higher values mean more "unnecessary" refreshes when the user
    /// happens to be idle near expiry; lower values leave a narrower window
    /// and risk falling back to the reactive 401 path on slow networks.
    static let proactiveRefreshBufferSeconds: TimeInterval = 300
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

    /// How long to keep retry tracking entries before cleanup.
    static let staleEntryThresholdSeconds: TimeInterval = 300
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

  // MARK: - Notifications

  enum Notifications {
    /// How far before the due date to fire the "due soon" notification.
    static let dueSoonOffsetSeconds: TimeInterval = 3600

    /// How far after the due date to fire the "overdue" notification.
    static let overdueOffsetSeconds: TimeInterval = 3600
  }

  // MARK: - Calendar

  enum Calendar {
    /// How many days back/forward to search for calendar events.
    static let syncWindowDays: Int = 30

    /// Default duration for calendar events created from tasks.
    static let eventDurationSeconds: TimeInterval = 3600

    /// How far before the event to trigger the alarm.
    static let eventAlarmOffsetSeconds: TimeInterval = 3600
  }
}
