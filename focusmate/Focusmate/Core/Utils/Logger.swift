import Foundation

/// Centralized logging utility for the Focusmate app
/// Automatically suppresses logs in Release builds
enum Logger {
    /// Log levels for categorizing messages
    enum Level: String {
        case debug = "🔍"
        case info = "ℹ️"
        case warning = "⚠️"
        case error = "❌"
        case success = "✅"
    }

    /// Print a debug message (only in DEBUG builds)
    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let filename = (file as NSString).lastPathComponent
        print("🔍 [\(filename):\(line)] \(message)")
        #endif
    }

    /// Print an info message (only in DEBUG builds)
    static func info(_ message: String) {
        #if DEBUG
        print("ℹ️ \(message)")
        #endif
    }

    /// Print a warning message (only in DEBUG builds)
    static func warning(_ message: String) {
        #if DEBUG
        print("⚠️ \(message)")
        #endif
    }

    /// Print an error message (shows in both DEBUG and RELEASE for critical errors)
    static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let filename = (file as NSString).lastPathComponent
        print("❌ ERROR [\(filename):\(line)] \(message)")

        // TODO: Send to crash reporting service (e.g., Sentry) in production
        #if !DEBUG
        // In production, send to error tracking
        // SentryService.shared.captureMessage(message, level: .error)
        #endif
    }

    /// Print a success message (only in DEBUG builds)
    static func success(_ message: String) {
        #if DEBUG
        print("✅ \(message)")
        #endif
    }

    /// Log a network request (only in DEBUG builds)
    static func network(_ message: String) {
        #if DEBUG
        print("🌐 \(message)")
        #endif
    }

    /// Log a database operation (only in DEBUG builds)
    static func database(_ message: String) {
        #if DEBUG
        print("💾 \(message)")
        #endif
    }

    /// Log a sync operation (only in DEBUG builds)
    static func sync(_ message: String) {
        #if DEBUG
        print("🔄 \(message)")
        #endif
    }

    /// Log a notification (only in DEBUG builds)
    static func notification(_ message: String) {
        #if DEBUG
        print("🔔 \(message)")
        #endif
    }

    /// Log a WebSocket message (only in DEBUG builds)
    static func websocket(_ message: String) {
        #if DEBUG
        print("🔌 \(message)")
        #endif
    }
}
