import Foundation
#if canImport(Sentry)
  import Sentry
#endif

/// Service for managing Sentry error tracking and monitoring
///
/// Thread Safety: Uses @MainActor to ensure all mutable state (`isInitialized`)
/// is accessed from a single thread. Without this, concurrent calls to `initialize()`
/// could race - both seeing `isInitialized == false` and double-initializing the SDK.
/// Tradeoff: Callers must await or be on main thread, adding slight dispatch overhead.
@MainActor
final class SentryService {
  static let shared = SentryService()

  private var isInitialized = false
  private var isSentryAvailable: Bool {
    #if canImport(Sentry)
      return true
    #else
      return false
    #endif
  }

  private init() {}

  /// Initialize Sentry SDK with DSN from environment or configuration
  func initialize() {
    guard !self.isInitialized else {
      Logger.warning("SentryService: Already initialized", category: .general)
      return
    }

    #if canImport(Sentry)
      // Get Sentry DSN from Info.plist or environment
      guard let dsn = getSentryDSN() else {
        Logger.warning("SentryService: No Sentry DSN found, skipping initialization", category: .general)
        return
      }

      SentrySDK.start { options in
        options.dsn = dsn

        // Set environment (development, staging, production)
        #if DEBUG
          options.environment = "development"
          options.debug = true
        #else
          options.environment = "production"
          options.debug = false
        #endif

        // Enable performance monitoring
        options.enableAutoPerformanceTracing = true
        options.tracesSampleRate = 1.0 // 100% of transactions

        // Enable automatic breadcrumbs
        options.enableAutoBreadcrumbTracking = true
        options.enableAutoSessionTracking = true

        // Network tracking
        options.enableNetworkTracking = true
        options.enableNetworkBreadcrumbs = true

        // Set release version
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        {
          options.releaseName = "\(version) (\(build))"
        }

        // Attach stack traces
        options.attachStacktrace = true

        // Sample rate for session replay (disabled by default)
        options.sessionReplaySampleRate = 0.0
        options.sessionReplayOnErrorSampleRate = 1.0 // Record sessions with errors

        Logger.info(
          "SentryService: Initialized with DSN for \(options.environment ?? "unknown") environment",
          category: .general
        )
      }

      self.isInitialized = true
    #else
      Logger.warning("SentryService: Sentry SDK not available. Add it via Swift Package Manager.", category: .general)
      Logger.info("See SENTRY_SETUP.md for installation instructions.", category: .general)
    #endif
  }

  /// Get Sentry DSN from configuration
  private func getSentryDSN() -> String? {
    // Try to get from Info.plist first
    if let dsn = Bundle.main.infoDictionary?["SENTRY_DSN"] as? String, !dsn.isEmpty {
      if dsn.contains("your-sentry-dsn@sentry.io") {
        Logger.warning(
          "SentryService: Placeholder Sentry DSN detected — set a real DSN in your xcconfig file",
          category: .general
        )
        return nil
      }
      return dsn
    }

    // Try environment variable (for CI/CD)
    if let dsn = ProcessInfo.processInfo.environment["SENTRY_DSN"], !dsn.isEmpty {
      return dsn
    }

    return nil
  }

  // MARK: - User Context

  /// Set user context for error tracking
  func setUser(id: Int, email: String, name: String) {
    #if canImport(Sentry)
      let user = User(userId: String(id))
      user.email = email
      user.username = name

      SentrySDK.setUser(user)
      Logger.info(
        "SentryService: User context set - ID: \(id), Email: \(Logger.sanitizeEmail(email))",
        category: .general
      )
    #else
      Logger.debug(
        "SentryService: Would set user - ID: \(id), Email: \(Logger.sanitizeEmail(email))",
        category: .general
      )
    #endif
  }

  /// Clear user context (on logout)
  func clearUser() {
    #if canImport(Sentry)
      SentrySDK.setUser(nil)
      Logger.info("SentryService: User context cleared", category: .general)
    #else
      Logger.debug("SentryService: Would clear user context", category: .general)
    #endif
  }

  // MARK: - Error Tracking

  /// Capture an error with additional context.
  /// Uses a local scope so tags don't leak between errors.
  func captureError(_ error: Error, context: [String: Any]? = nil) {
    #if canImport(Sentry)
      SentrySDK.capture(error: error) { scope in
        if let context {
          for (key, value) in context {
            scope.setTag(value: String(describing: value), key: key)
          }
        }
      }
      Logger.debug("SentryService: Captured error - \(error)", category: .general)
    #else
      Logger.debug("SentryService: Would capture error - \(error)", category: .general)
      if let context {
        Logger.debug("Context: \(context)", category: .general)
      }
    #endif
  }

  /// Capture a message with level
  func captureMessage(_ message: String, level: SentryLevel = .info) {
    #if canImport(Sentry)
      SentrySDK.capture(message: message) { scope in
        scope.setLevel(level)
      }
      Logger.debug("SentryService: Captured message [\(level)] - \(message)", category: .general)
    #else
      Logger.debug("SentryService: Would capture message [\(level.description)] - \(message)", category: .general)
    #endif
  }

  /// Capture exception with custom fingerprint for grouping
  func captureException(_ error: Error, fingerprint: [String]? = nil) {
    #if canImport(Sentry)
      SentrySDK.capture(error: error) { scope in
        if let fingerprint {
          scope.setFingerprint(fingerprint)
        }
      }
    #else
      Logger.debug("SentryService: Would capture exception - \(error)", category: .general)
      if let fingerprint {
        Logger.debug("Fingerprint: \(fingerprint)", category: .general)
      }
    #endif
  }

  // MARK: - Breadcrumbs

  /// Add a breadcrumb for tracking user actions
  func addBreadcrumb(message: String, category: String, level: SentryLevel = .info, data: [String: Any]? = nil) {
    #if canImport(Sentry)
      let breadcrumb = Breadcrumb(level: level, category: category)
      breadcrumb.message = message
      breadcrumb.type = "default"

      if let data {
        breadcrumb.data = data
      }

      SentrySDK.addBreadcrumb(breadcrumb)
    #else
      Logger.debug("SentryService: Breadcrumb [\(category)] - \(message)", category: .general)
    #endif
  }

  /// Add navigation breadcrumb
  func addNavigationBreadcrumb(from: String, to: String) {
    self.addBreadcrumb(
      message: "Navigation: \(from) → \(to)",
      category: "navigation",
      level: .info,
      data: ["from": from, "to": to]
    )
  }

  /// Add API call breadcrumb
  func addAPIBreadcrumb(method: String, endpoint: String, statusCode: Int? = nil) {
    var data: [String: Any] = ["method": method, "endpoint": endpoint]
    if let statusCode {
      data["status_code"] = statusCode
    }

    self.addBreadcrumb(
      message: "\(method) \(endpoint)",
      category: "api",
      level: (statusCode ?? 0) >= 400 ? .warning : .info,
      data: data
    )
  }

  /// Add user action breadcrumb
  func addUserActionBreadcrumb(action: String, details: [String: Any]? = nil) {
    self.addBreadcrumb(
      message: "User action: \(action)",
      category: "user",
      level: .info,
      data: details
    )
  }

  // MARK: - Performance Monitoring

  #if canImport(Sentry)
    /// Start a transaction for performance monitoring
    func startTransaction(name: String, operation: String) -> Span? {
      return SentrySDK.startTransaction(name: name, operation: operation)
    }

    /// Finish a transaction
    func finishTransaction(_ transaction: Span?, status: SpanStatus = .ok) {
      transaction?.finish(status: status)
    }
  #endif

  /// Measure a block of code
  func measure<T>(name: String, operation: String = "function", _ block: () throws -> T) rethrows -> T {
    #if canImport(Sentry)
      let transaction = self.startTransaction(name: name, operation: operation)
      defer {
        finishTransaction(transaction)
      }
      return try block()
    #else
      return try block()
    #endif
  }

  /// Measure an async block of code
  func measureAsync<T>(
    name: String,
    operation: String = "function",
    _ block: () async throws -> T
  ) async rethrows -> T {
    #if canImport(Sentry)
      let transaction = self.startTransaction(name: name, operation: operation)
      defer {
        finishTransaction(transaction)
      }
      return try await block()
    #else
      return try await block()
    #endif
  }

  // MARK: - Context

  /// Set custom context for debugging
  func setContext(_ context: [String: Any], key: String) {
    #if canImport(Sentry)
      SentrySDK.configureScope { scope in
        scope.setContext(value: context, key: key)
      }
    #else
      Logger.debug("SentryService: Would set context [\(key)] - \(context)", category: .general)
    #endif
  }

  /// Set a tag for filtering
  func setTag(value: String, key: String) {
    #if canImport(Sentry)
      SentrySDK.configureScope { scope in
        scope.setTag(value: value, key: key)
      }
    #else
      Logger.debug("SentryService: Would set tag [\(key)] = \(value)", category: .general)
    #endif
  }

  /// Set extra data
  func setExtra(value: Any, key: String) {
    #if canImport(Sentry)
      SentrySDK.configureScope { scope in
        scope.setExtra(value: value, key: key)
      }
    #else
      Logger.debug("SentryService: Would set extra [\(key)] = \(value)", category: .general)
    #endif
  }

  // MARK: - Session Management

  /// Start a new session
  func startSession() {
    #if canImport(Sentry)
      SentrySDK.startSession()
      Logger.info("SentryService: Session started", category: .general)
    #else
      Logger.debug("SentryService: Would start session", category: .general)
    #endif
  }

  /// End current session
  func endSession() {
    #if canImport(Sentry)
      SentrySDK.endSession()
      Logger.info("SentryService: Session ended", category: .general)
    #else
      Logger.debug("SentryService: Would end session", category: .general)
    #endif
  }

  // MARK: - Flush

  /// Flush pending events (useful before app termination)
  func flush(timeout: TimeInterval = 2.0) async {
    #if canImport(Sentry)
      await withCheckedContinuation { continuation in
        SentrySDK.flush(timeout: timeout) {
          Logger.info("SentryService: Flushed pending events", category: .general)
          continuation.resume()
        }
      }
    #else
      Logger.debug("SentryService: Would flush pending events", category: .general)
    #endif
  }

  // MARK: - Testing

  /// Test Sentry integration (for debugging)
  func testIntegration() {
    #if canImport(Sentry)
      SentrySDK.capture(message: "Sentry iOS integration test")
      Logger.debug("SentryService: Test message sent to Sentry", category: .general)
    #else
      Logger.debug("SentryService: Would send test message (Sentry SDK not available)", category: .general)
    #endif
  }
}

// MARK: - Convenience Extensions

#if canImport(Sentry)
  extension SentryLevel {
    var description: String {
      switch self {
      case .debug: return "debug"
      case .info: return "info"
      case .warning: return "warning"
      case .error: return "error"
      case .fatal: return "fatal"
      @unknown default: return "unknown"
      }
    }
  }
#else
  /// Mock SentryLevel for when Sentry is not available
  enum SentryLevel {
    case debug, info, warning, error, fatal

    var description: String {
      switch self {
      case .debug: return "debug"
      case .info: return "info"
      case .warning: return "warning"
      case .error: return "error"
      case .fatal: return "fatal"
      }
    }
  }
#endif
