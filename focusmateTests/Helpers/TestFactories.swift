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
        hidden: Bool? = nil,
        position: Int? = nil,
        status: String? = nil,
        canEdit: Bool? = true,
        canDelete: Bool? = true,
        createdAt: String? = nil,
        updatedAt: String? = nil,
        tags: [TagDTO]? = nil,
        rescheduleEvents: [RescheduleEventDTO]? = nil,
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
        missedReasonSubmittedAt: String? = nil,
        creator: TaskCreatorDTO? = nil
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
            hidden: hidden,
            position: position,
            status: status,
            can_edit: canEdit,
            can_delete: canDelete,
            created_at: createdAt,
            updated_at: updatedAt,
            tags: tags,
            reschedule_events: rescheduleEvents,
            parent_task_id: parentTaskId,
            subtasks: subtasks,
            creator: creator,
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
        listType: String? = nil,
        role: String? = "owner",
        tasksCount: Int? = 0,
        parentTasksCount: Int? = nil,
        completedTasksCount: Int? = nil,
        overdueTasksCount: Int? = nil,
        members: [ListMemberDTO]? = nil,
        tags: [TagDTO]? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) -> ListDTO {
        ListDTO(
            id: id,
            name: name,
            description: description,
            visibility: visibility,
            color: color,
            list_type: listType,
            role: role,
            tasks_count: tasksCount,
            parent_tasks_count: parentTasksCount,
            completed_tasks_count: completedTasksCount,
            overdue_tasks_count: overdueTasksCount,
            members: members,
            tags: tags,
            created_at: createdAt,
            updated_at: updatedAt
        )
    }

    // MARK: - SubtaskDTO

    static func makeSampleSubtask(
        id: Int = 100,
        taskId: Int? = 1,
        title: String = "Test Subtask",
        note: String? = nil,
        status: String? = nil,
        completedAt: String? = nil,
        position: Int? = nil,
        createdAt: String? = nil
    ) -> SubtaskDTO {
        SubtaskDTO(
            id: id,
            task_id: taskId,
            title: title,
            note: note,
            status: status,
            completed_at: completedAt,
            position: position,
            created_at: createdAt
        )
    }

    // MARK: - InviteDTO

    static func makeSampleInvite(
        id: Int = 1,
        code: String = "ABC123",
        inviteUrl: String = "https://focusmate.app/invite/ABC123",
        role: String = "viewer",
        usesCount: Int = 0,
        maxUses: Int? = nil,
        expiresAt: String? = nil,
        usable: Bool = true
    ) -> InviteDTO {
        InviteDTO(
            id: id,
            code: code,
            invite_url: inviteUrl,
            role: role,
            uses_count: usesCount,
            max_uses: maxUses,
            expires_at: expiresAt,
            usable: usable
        )
    }

    // MARK: - InvitePreviewDTO

    static func makeSampleInvitePreview(
        code: String = "ABC123",
        role: String = "viewer",
        listId: Int = 1,
        listName: String = "Test List",
        listColor: String = "blue",
        inviterName: String? = "John",
        usable: Bool = true,
        expired: Bool = false,
        exhausted: Bool = false
    ) -> InvitePreviewDTO {
        InvitePreviewDTO(
            code: code,
            role: role,
            list: .init(id: listId, name: listName, color: listColor),
            inviter: inviterName.map { .init(name: $0) },
            usable: usable,
            expired: expired,
            exhausted: exhausted
        )
    }

    // MARK: - FriendDTO

    static func makeSampleFriend(
        id: Int = 1,
        name: String? = "Alice",
        email: String? = "alice@example.com"
    ) -> FriendDTO {
        FriendDTO(id: id, name: name, email: email)
    }

    // MARK: - MembershipDTO

    static func makeSampleMembership(
        id: Int = 1,
        userId: Int = 10,
        userEmail: String? = "user@example.com",
        userName: String? = "User",
        role: String = "editor"
    ) -> MembershipDTO {
        MembershipDTO(
            id: id,
            user: MemberUser(id: userId, email: userEmail, name: userName),
            role: role,
            created_at: nil,
            updated_at: nil
        )
    }

    // MARK: - TagDTO

    static func makeSampleTag(
        id: Int = 1,
        name: String = "Work",
        color: String? = "blue",
        tasksCount: Int? = nil,
        createdAt: String? = nil
    ) -> TagDTO {
        TagDTO(id: id, name: name, color: color, tasks_count: tasksCount, created_at: createdAt)
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
    ///
    /// - Note: Uses preconditionFailure for invalid dates since these are test utilities
    ///   with hardcoded valid inputs. A failure here indicates a programming error.
    static func isoString(daysFromNow days: Int, hour: Int = 12, minute: Int = 0) -> String {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.day = (components.day ?? 0) + days
        components.hour = hour
        components.minute = minute
        components.second = 0
        guard let date = calendar.date(from: components) else {
            preconditionFailure("Failed to create date from components: \(components)")
        }
        return isoFormatter.string(from: date)
    }

    /// Returns an ISO8601 string for midnight (start of day) relative to now.
    static func midnightISOString(daysFromNow days: Int) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let target = calendar.date(byAdding: .day, value: days, to: today) else {
            preconditionFailure("Failed to add \(days) days to \(today)")
        }
        return isoFormatter.string(from: target)
    }
}
