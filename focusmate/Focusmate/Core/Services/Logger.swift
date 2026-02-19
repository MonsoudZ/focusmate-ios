import Foundation
import os.log

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

enum LogCategory: String {
  case auth = "Auth"
  case api = "API"
  case ui = "UI"
  case general = "General"

  var osLog: OSLog {
    OSLog(subsystem: "com.intentia.app", category: rawValue)
  }
}

final class Logger {
  static let minimumLevel: LogLevel = {
    #if DEBUG
      return .debug
    #else
      return .error
    #endif
  }()

  static let consoleLoggingEnabled: Bool = {
    #if DEBUG
      return true
    #else
      return false
    #endif
  }()

  static let osLogEnabled: Bool = true

  static func debug(
    _ message: String,
    category: LogCategory = .general,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) {
    self.log(.debug, message, category: category, file: file, function: function, line: line)
  }

  static func info(
    _ message: String,
    category: LogCategory = .general,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) {
    self.log(.info, message, category: category, file: file, function: function, line: line)
  }

  static func warning(
    _ message: String,
    category: LogCategory = .general,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) {
    self.log(.warning, message, category: category, file: file, function: function, line: line)
  }

  static func error(
    _ message: String,
    error: Error? = nil,
    category: LogCategory = .general,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) {
    var fullMessage = message
    if let error {
      fullMessage += " | Error: \(error.localizedDescription)"
    }

    self.log(.error, fullMessage, category: category, file: file, function: function, line: line)

    #if !DEBUG
      // Fire-and-forget on MainActor — SentryService is @MainActor isolated.
      // Without this Task wrapper, the compiler infers Logger.error() itself as
      // MainActor-isolated (synchronous access to an @MainActor singleton),
      // which would prevent calling Logger.error() from background threads.
      let file = self.filename(from: file)
      if let error {
        Task { @MainActor in
          SentryService.shared.captureError(
            error,
            context: [
              "message": message,
              "file": file,
              "function": function,
              "line": line,
            ]
          )
        }
      } else {
        let contextMessage = "\(fullMessage) [file: \(file), function: \(function), line: \(line)]"
        Task { @MainActor in
          SentryService.shared.captureMessage(contextMessage)
        }
      }
    #endif
  }

  private static func log(
    _ level: LogLevel,
    _ message: String,
    category: LogCategory,
    file: String,
    function: String,
    line: Int
  ) {
    guard level >= self.minimumLevel else { return }

    let filename = self.filename(from: file)
    let timestamp = self.timestampString()

    if self.consoleLoggingEnabled {
      let logMessage = self.formatConsoleMessage(
        level: level,
        message: message,
        category: category,
        filename: filename,
        line: line,
        timestamp: timestamp
      )
      print(logMessage)
    }

    if self.osLogEnabled {
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
    line: Int,
    timestamp: String
  ) -> String {
    #if DEBUG
      return "[\(timestamp)] \(level.emoji) [\(category.rawValue)] \(filename):\(line) - \(message)"
    #else
      return "[\(timestamp)] \(level.emoji) \(message)"
    #endif
  }

  private static func filename(from path: String) -> String {
    (path as NSString).lastPathComponent
  }

  /// Thread-safe timestamp generation.
  /// Uses NSLock to protect the cached DateFormatter since DateFormatter
  /// is not thread-safe (its internal ICU state can corrupt under concurrent access).
  private static let timestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    return formatter
  }()

  private static let timestampLock = NSLock()

  private static func timestampString() -> String {
    self.timestampLock.lock()
    defer { timestampLock.unlock() }
    return self.timestampFormatter.string(from: Date())
  }
}

extension Logger {
  static func sanitizeEmail(_ string: String) -> String {
    let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    return string.replacingOccurrences(of: pattern, with: "[EMAIL]", options: .regularExpression)
  }

  static func sanitizeToken(_ string: String) -> String {
    var result = string

    // Bearer tokens (Authorization header)
    result = result.replacingOccurrences(
      of: "Bearer [A-Za-z0-9._-]+",
      with: "Bearer [TOKEN]",
      options: .regularExpression
    )

    // JWT tokens (three base64 segments separated by dots)
    result = result.replacingOccurrences(
      of: "eyJ[A-Za-z0-9_-]*\\.[A-Za-z0-9_-]*\\.[A-Za-z0-9_-]*",
      with: "[JWT]",
      options: .regularExpression
    )

    // Generic long alphanumeric strings that look like tokens (40+ chars)
    result = result.replacingOccurrences(
      of: "(?<![A-Za-z0-9])[A-Za-z0-9_-]{40,}(?![A-Za-z0-9])",
      with: "[TOKEN]",
      options: .regularExpression
    )

    return result
  }

  static func sanitize(_ string: String) -> String {
    var sanitized = string
    sanitized = self.sanitizeEmail(sanitized)
    sanitized = self.sanitizeToken(sanitized)
    return sanitized
  }
}
