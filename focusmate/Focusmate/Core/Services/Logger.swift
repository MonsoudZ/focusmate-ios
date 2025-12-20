import Foundation
import os.log

/// Log levels for filtering and categorization
enum LogLevel: Int, Comparable {
  case debug = 0
  case info = 1
  case warning = 2
  case error = 3

  static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  var emoji: String {
    switch self {
    case .debug: return "🔍"
    case .info: return "ℹ️"
    case .warning: return "⚠️"
    case .error: return "❌"
    }
  }

  var osLogType: OSLogType {
    switch self {
    case .debug: return .debug
    case .info: return .info
    case .warning: return .default
    case .error: return .error
    }
  }
}

/// Category for organizing logs
enum LogCategory: String {
  case auth = "Auth"
  case api = "API"
  case sync = "Sync"
  case database = "Database"
  case websocket = "WebSocket"
  case location = "Location"
  case notification = "Notification"
  case ui = "UI"
  case general = "General"

  var osLog: OSLog {
    OSLog(subsystem: "com.focusmate.app", category: rawValue)
  }
}

/// Centralized logging service with support for different environments
/// Replaces all print() statements with structured logging
final class Logger {

  // MARK: - Configuration

  /// Minimum log level to display
  /// Debug builds: Show all logs
  /// Release builds: Only show errors
  static var minimumLevel: LogLevel = {
    #if DEBUG
    return .debug
    #else
    return .error
    #endif
  }()

  /// Enable console logging (always enabled in debug, disabled in release)
  static var consoleLoggingEnabled: Bool = {
    #if DEBUG
    return true
    #else
    return false
    #endif
  }()

  /// Enable OSLog (unified logging system)
  static var osLogEnabled: Bool = true

  // MARK: - Public API

  /// Log a debug message (only in debug builds)
  static func debug(
    _ message: String,
    category: LogCategory = .general,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) {
    log(.debug, message, category: category, file: file, function: function, line: line)
  }

  /// Log an info message
  static func info(
    _ message: String,
    category: LogCategory = .general,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) {
    log(.info, message, category: category, file: file, function: function, line: line)
  }

  /// Log a warning message
  static func warning(
    _ message: String,
    category: LogCategory = .general,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) {
    log(.warning, message, category: category, file: file, function: function, line: line)
  }

  /// Log an error message (always logged, even in release)
  static func error(
    _ message: String,
    error: Error? = nil,
    category: LogCategory = .general,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) {
    var fullMessage = message
    if let error = error {
      fullMessage += " | Error: \(error.localizedDescription)"
    }

    log(.error, fullMessage, category: category, file: file, function: function, line: line)

    // Report errors to Sentry in production
    #if !DEBUG
    if let error = error {
      SentryService.shared.captureError(
        error,
        context: [
          "message": message,
          "file": filename(from: file),
          "function": function,
          "line": line
        ]
      )
    } else {
      // captureMessage doesn't support context parameter, include context in message
      let contextMessage = "\(fullMessage) [file: \(filename(from: file)), function: \(function), line: \(line)]"
      SentryService.shared.captureMessage(contextMessage)
    }
    #endif
  }

  // MARK: - Private Implementation

  private static func log(
    _ level: LogLevel,
    _ message: String,
    category: LogCategory,
    file: String,
    function: String,
    line: Int
  ) {
    // Check minimum level
    guard level >= minimumLevel else { return }

    let filename = self.filename(from: file)
    let timestamp = timestampString()

    // Console logging (debug only)
    if consoleLoggingEnabled {
      let logMessage = formatConsoleMessage(
        level: level,
        message: message,
        category: category,
        filename: filename,
        function: function,
        line: line,
        timestamp: timestamp
      )
      print(logMessage)
    }

    // OSLog (unified logging)
    if osLogEnabled {
      os_log(
        level.osLogType,
        log: category.osLog,
        "%{public}@",
        message
      )
    }
  }

  private static func formatConsoleMessage(
    level: LogLevel,
    message: String,
    category: LogCategory,
    filename: String,
    function: String,
    line: Int,
    timestamp: String
  ) -> String {
    #if DEBUG
    // Verbose format for debugging
    return "[\(timestamp)] \(level.emoji) [\(category.rawValue)] \(filename):\(line) - \(message)"
    #else
    // Minimal format for production (if console logging enabled)
    return "[\(timestamp)] \(level.emoji) \(message)"
    #endif
  }

  private static func filename(from path: String) -> String {
    (path as NSString).lastPathComponent
  }

  private static func timestampString() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    return formatter.string(from: Date())
  }
}

// MARK: - Data Sanitization

extension Logger {
  /// Sanitize email addresses from strings
  static func sanitizeEmail(_ string: String) -> String {
    let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    return string.replacingOccurrences(
      of: pattern,
      with: "[EMAIL]",
      options: .regularExpression
    )
  }

  /// Sanitize tokens from strings
  static func sanitizeToken(_ string: String) -> String {
    let pattern = "Bearer [A-Za-z0-9._-]+"
    return string.replacingOccurrences(
      of: pattern,
      with: "Bearer [TOKEN]",
      options: .regularExpression
    )
  }

  /// Sanitize sensitive data (emails, tokens, etc.)
  static func sanitize(_ string: String) -> String {
    var sanitized = string
    sanitized = sanitizeEmail(sanitized)
    sanitized = sanitizeToken(sanitized)
    return sanitized
  }
}
