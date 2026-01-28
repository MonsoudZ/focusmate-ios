import Foundation
import SwiftUI

private let _iso8601Formatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

private let _iso8601FormatterNoFrac: ISO8601DateFormatter = {
    ISO8601DateFormatter()
}()

struct TaskDTO: Codable, Identifiable {
    let id: Int
    let list_id: Int
    let list_name: String?
    let color: String?
    let title: String
    let note: String?
    let due_at: String?
    var completed_at: String?
    let priority: Int?
    var starred: Bool?
    var position: Int?
    let status: String?
    let can_edit: Bool?
    let can_delete: Bool?
    let created_at: String?
    let updated_at: String?
    let tags: [TagDTO]?
    let parent_task_id: Int?
    var subtasks: [SubtaskDTO]?

    // Recurring fields
    let is_recurring: Bool?
    let recurrence_pattern: String?
    let recurrence_interval: Int?
    let recurrence_days: [Int]?
    let recurrence_end_date: String?
    let recurrence_count: Int?
    let template_id: Int?
    let instance_date: String?
    let instance_number: Int?

    let overdue: Bool?
    let minutes_overdue: Int?
    let requires_explanation_if_missed: Bool?
    let missed_reason: String?
    let missed_reason_submitted_at: String?

    // MARK: - Computed Properties

    var isCompleted: Bool {
        completed_at != nil
    }

    var isOverdue: Bool {
        overdue ?? false
    }

    var isStarred: Bool {
        starred ?? false
    }

    var isRecurring: Bool {
        is_recurring ?? false
    }

    var isRecurringInstance: Bool {
        template_id != nil
    }

    var needsReason: Bool {
        isOverdue && (requires_explanation_if_missed ?? false) && missed_reason == nil
    }

    var dueDate: Date? {
        guard let due_at else { return nil }
        return _iso8601Formatter.date(from: due_at)
            ?? _iso8601FormatterNoFrac.date(from: due_at)
    }

    var taskPriority: TaskPriority {
        TaskPriority(rawValue: priority ?? 0) ?? .none
    }

    var taskColor: Color {
        switch color {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "pink": return .pink
        case "teal": return .teal
        case "yellow": return .yellow
        case "gray": return .gray
        default: return .blue
        }
    }

    var isAnytime: Bool {
        guard let dueDate = dueDate else { return false }
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: dueDate)
        let minute = calendar.component(.minute, from: dueDate)
        return hour == 0 && minute == 0
    }

    var isActuallyOverdue: Bool {
        guard let dueDate = dueDate, !isCompleted else { return false }

        let now = Date()

        if isAnytime {
            // "Anytime" tasks are due by end of the calendar day in the user's
            // local timezone.  Calendar.current uses the device timezone, which
            // matches the server's expectation (due_at is midnight user-tz).
            let calendar = Calendar.current
            guard let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: dueDate)) else {
                return false
            }
            return now >= startOfNextDay
        }

        return now > dueDate
    }

    var recurrenceDescription: String? {
        guard isRecurringInstance || isRecurring else { return nil }

        let interval = recurrence_interval ?? 1

        switch recurrence_pattern {
        case "daily":
            return interval == 1 ? "Daily" : "Every \(interval) days"
        case "weekly":
            if let days = recurrence_days, !days.isEmpty {
                let dayNames = days.compactMap { dayName(for: $0) }
                return interval == 1 ? "Weekly on \(dayNames.joined(separator: ", "))" : "Every \(interval) weeks"
            }
            return interval == 1 ? "Weekly" : "Every \(interval) weeks"
        case "monthly":
            return interval == 1 ? "Monthly" : "Every \(interval) months"
        case "yearly":
            return interval == 1 ? "Yearly" : "Every \(interval) years"
        default:
            return nil
        }
    }

    private func dayName(for day: Int) -> String? {
        switch day {
        case 0: return "Sun"
        case 1: return "Mon"
        case 2: return "Tue"
        case 3: return "Wed"
        case 4: return "Thu"
        case 5: return "Fri"
        case 6: return "Sat"
        default: return nil
        }
    }

    // MARK: - Subtask Helpers

    var hasSubtasks: Bool {
        guard let subtasks = subtasks else { return false }
        return !subtasks.isEmpty
    }

    var subtaskCount: Int {
        subtasks?.count ?? 0
    }

    var completedSubtaskCount: Int {
        subtasks?.filter { $0.isCompleted }.count ?? 0
    }

    var subtaskProgress: String {
        "\(completedSubtaskCount)/\(subtaskCount)"
    }

    var isSubtask: Bool {
        parent_task_id != nil
    }
}

struct TasksResponse: Codable {
    let tasks: [TaskDTO]
    let tombstones: [String]?
}
