import Foundation

/// Centralized due-date formatting with cached `DateFormatter` instances.
///
/// `DateFormatter` init triggers ICU library setup — pattern compilation, locale data
/// loading, heap allocation (~200-400us, ~1-2KB per instance). By caching formatters as
/// `static let`, we pay that cost once at app launch instead of on every SwiftUI body
/// evaluation. The tradeoff: these formatters live for the process lifetime (~5 formatters
/// x ~1-2KB = negligible), and we give up automatic locale-change reactivity (acceptable
/// because iOS restarts the process on locale change anyway).
enum DueDateFormatter {

    // MARK: - Cached Formatters

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f
    }()

    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    private static let fullDateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return f
    }()

    // MARK: - Public API

    /// Compact format for task rows — no year, "Today 3:30 PM", includes "Yesterday".
    static func compact(_ date: Date, isAnytime: Bool) -> String {
        let calendar = Calendar.current

        if isAnytime {
            if calendar.isDateInToday(date) { return "Today" }
            if calendar.isDateInTomorrow(date) { return "Tomorrow" }
            if calendar.isDateInYesterday(date) { return "Yesterday" }
            return dateFormatter.string(from: date)
        }

        if calendar.isDateInToday(date) {
            return "Today \(timeFormatter.string(from: date))"
        }
        if calendar.isDateInTomorrow(date) {
            return "Tomorrow \(timeFormatter.string(from: date))"
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday \(timeFormatter.string(from: date))"
        }
        return dateTimeFormatter.string(from: date)
    }

    /// Full format for detail views — includes year, "Today at 3:30 PM".
    static func full(_ date: Date, isAnytime: Bool) -> String {
        let calendar = Calendar.current

        if isAnytime {
            if calendar.isDateInToday(date) { return "Today" }
            if calendar.isDateInTomorrow(date) { return "Tomorrow" }
            return fullDateFormatter.string(from: date)
        }

        if calendar.isDateInToday(date) {
            return "Today at \(timeFormatter.string(from: date))"
        }
        if calendar.isDateInTomorrow(date) {
            return "Tomorrow at \(timeFormatter.string(from: date))"
        }
        return fullDateTimeFormatter.string(from: date)
    }

    /// Human-readable overdue duration string.
    static func formatOverdue(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m overdue" }
        if minutes < 1440 { return "\(minutes / 60)h overdue" }
        return "\(minutes / 1440)d overdue"
    }
}
