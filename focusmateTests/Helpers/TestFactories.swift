import Foundation
@testable import focusmate

enum TestFactories {

    // MARK: - TaskDTO

    static func makeSampleTask(
        id: Int = 1,
        listId: Int = 1,
        listName: String? = "Test List",
        color: String? = nil,
        title: String = "Test Task",
        note: String? = nil,
        dueAt: String? = nil,
        completedAt: String? = nil,
        priority: Int? = nil,
        starred: Bool? = nil,
        position: Int? = nil,
        status: String? = nil,
        canEdit: Bool? = true,
        canDelete: Bool? = true,
        createdAt: String? = nil,
        updatedAt: String? = nil,
        tags: [TagDTO]? = nil,
        parentTaskId: Int? = nil,
        subtasks: [SubtaskDTO]? = nil,
        isRecurring: Bool? = nil,
        recurrencePattern: String? = nil,
        recurrenceInterval: Int? = nil,
        recurrenceDays: [Int]? = nil,
        recurrenceEndDate: String? = nil,
        recurrenceCount: Int? = nil,
        templateId: Int? = nil,
        instanceDate: String? = nil,
        instanceNumber: Int? = nil,
        overdue: Bool? = nil,
        minutesOverdue: Int? = nil,
        requiresExplanationIfMissed: Bool? = nil,
        missedReason: String? = nil,
        missedReasonSubmittedAt: String? = nil
    ) -> TaskDTO {
        TaskDTO(
            id: id,
            list_id: listId,
            list_name: listName,
            color: color,
            title: title,
            note: note,
            due_at: dueAt,
            completed_at: completedAt,
            priority: priority,
            starred: starred,
            position: position,
            status: status,
            can_edit: canEdit,
            can_delete: canDelete,
            created_at: createdAt,
            updated_at: updatedAt,
            tags: tags,
            parent_task_id: parentTaskId,
            subtasks: subtasks,
            is_recurring: isRecurring,
            recurrence_pattern: recurrencePattern,
            recurrence_interval: recurrenceInterval,
            recurrence_days: recurrenceDays,
            recurrence_end_date: recurrenceEndDate,
            recurrence_count: recurrenceCount,
            template_id: templateId,
            instance_date: instanceDate,
            instance_number: instanceNumber,
            overdue: overdue,
            minutes_overdue: minutesOverdue,
            requires_explanation_if_missed: requiresExplanationIfMissed,
            missed_reason: missedReason,
            missed_reason_submitted_at: missedReasonSubmittedAt
        )
    }

    // MARK: - ListDTO

    static func makeSampleList(
        id: Int = 1,
        name: String = "Test List",
        description: String? = nil,
        visibility: String = "private",
        color: String? = "blue",
        role: String? = "owner",
        tasksCount: Int? = 0,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) -> ListDTO {
        ListDTO(
            id: id,
            name: name,
            description: description,
            visibility: visibility,
            color: color,
            role: role,
            tasks_count: tasksCount,
            created_at: createdAt,
            updated_at: updatedAt
        )
    }

    // MARK: - SubtaskDTO

    static func makeSampleSubtask(
        id: Int = 100,
        title: String = "Test Subtask",
        note: String? = nil,
        status: String? = nil,
        completedAt: String? = nil,
        position: Int? = nil,
        createdAt: String? = nil
    ) -> SubtaskDTO {
        SubtaskDTO(
            id: id,
            title: title,
            note: note,
            status: status,
            completed_at: completedAt,
            position: position,
            created_at: createdAt
        )
    }

    // MARK: - Helpers

    static let isoFormatter: ISO8601DateFormatter = {
        ISO8601DateFormatter()
    }()

    static let isoFormatterWithFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Returns an ISO8601 string for a date relative to now.
    static func isoString(daysFromNow days: Int, hour: Int = 12, minute: Int = 0) -> String {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.day! += days
        components.hour = hour
        components.minute = minute
        components.second = 0
        let date = calendar.date(from: components)!
        return isoFormatter.string(from: date)
    }

    /// Returns an ISO8601 string for midnight (start of day) relative to now.
    static func midnightISOString(daysFromNow days: Int) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.date(byAdding: .day, value: days, to: today)!
        return isoFormatter.string(from: target)
    }
}
