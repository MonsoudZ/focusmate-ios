import Foundation

private let _iso8601Formatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

private let _iso8601FormatterNoFrac: ISO8601DateFormatter = {
    ISO8601DateFormatter()
}()

struct RescheduleEventDTO: Codable, Identifiable, Hashable {
    let id: Int
    let task_id: Int
    let previous_due_at: String?
    let new_due_at: String?
    let reason: String
    let created_at: String?

    var previousDueDate: Date? {
        guard let previous_due_at else { return nil }
        return _iso8601Formatter.date(from: previous_due_at)
            ?? _iso8601FormatterNoFrac.date(from: previous_due_at)
    }

    var newDueDate: Date? {
        guard let new_due_at else { return nil }
        return _iso8601Formatter.date(from: new_due_at)
            ?? _iso8601FormatterNoFrac.date(from: new_due_at)
    }

    var createdDate: Date? {
        guard let created_at else { return nil }
        return _iso8601Formatter.date(from: created_at)
            ?? _iso8601FormatterNoFrac.date(from: created_at)
    }

    var reasonLabel: String {
        switch reason {
        case "scope_changed": return "Scope changed"
        case "priorities_shifted": return "Priorities shifted"
        case "blocked": return "Waiting on someone/something"
        case "underestimated": return "Underestimated time needed"
        case "unexpected_work": return "Unexpected work came up"
        case "not_ready": return "Not ready to start yet"
        case "other": return "Other"
        default: return reason
        }
    }
}
