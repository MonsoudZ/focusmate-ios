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

    static var minimumLevel: LogLevel = {
        #if DEBUG
        return .debug
        #else
        return .error
        #endif
    }()

    static var consoleLoggingEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    static var osLogEnabled: Bool = true

    static func debug(
        _ message: String,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(.debug, message, category: category, file: file, function: function, line: line)
    }

    static func info(
        _ message: String,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(.info, message, category: category, file: file, function: function, line: line)
    }

    static func warning(
        _ message: String,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(.warning, message, category: category, file: file, function: function, line: line)
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
        if let error = error {
            fullMessage += " | Error: \(error.localizedDescription)"
        }

        log(.error, fullMessage, category: category, file: file, function: function, line: line)

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
            let contextMessage = "\(fullMessage) [file: \(filename(from: file)), function: \(function), line: \(line)]"
            SentryService.shared.captureMessage(contextMessage)
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
        guard level >= minimumLevel else { return }

        let filename = self.filename(from: file)
        let timestamp = timestampString()

        if consoleLoggingEnabled {
            let logMessage = formatConsoleMessage(
                level: level,
                message: message,
                category: category,
                filename: filename,
                line: line,
                timestamp: timestamp
            )
            print(logMessage)
        }

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

    /// Cached DateFormatter for thread-safe timestamp generation.
    /// DateFormatter is expensive to create, so we cache a static instance.
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    private static func timestampString() -> String {
        timestampFormatter.string(from: Date())
    }
}

extension Logger {
    static func sanitizeEmail(_ string: String) -> String {
        let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return string.replacingOccurrences(of: pattern, with: "[EMAIL]", options: .regularExpression)
    }

    static func sanitizeToken(_ string: String) -> String {
        let pattern = "Bearer [A-Za-z0-9._-]+"
        return string.replacingOccurrences(of: pattern, with: "Bearer [TOKEN]", options: .regularExpression)
    }

    static func sanitize(_ string: String) -> String {
        var sanitized = string
        sanitized = sanitizeEmail(sanitized)
        sanitized = sanitizeToken(sanitized)
        return sanitized
    }
}
