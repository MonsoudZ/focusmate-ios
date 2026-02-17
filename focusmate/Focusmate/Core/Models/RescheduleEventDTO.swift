import Foundation

struct RescheduledByDTO: Codable, Hashable {
    let id: Int
    let name: String?
}

struct RescheduleEventDTO: Codable, Identifiable, Hashable {
    let id: Int
    let task_id: Int?
    let original_due_at: String?
    let new_due_at: String?
    let reason: String?
    let rescheduled_by: RescheduledByDTO?
    let created_at: String?

    var previousDueDate: Date? {
        guard let original_due_at else { return nil }
        return ISO8601Utils.parseDate(original_due_at)
    }

    var newDueDate: Date? {
        guard let new_due_at else { return nil }
        return ISO8601Utils.parseDate(new_due_at)
    }

    var createdDate: Date? {
        guard let created_at else { return nil }
        return ISO8601Utils.parseDate(created_at)
    }

    var reasonLabel: String {
        guard let reason else { return "Rescheduled" }
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
