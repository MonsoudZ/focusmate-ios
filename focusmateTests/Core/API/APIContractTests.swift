import XCTest
@testable import focusmate

/// Tests that iOS DTOs correctly decode real backend JSON shapes.
///
/// **Why these tests matter:**
/// Swift's `Codable` synthesizes memberwise initializers that encode/decode all
/// stored properties.  When a DTO is round-tripped through Swift's own encoder
/// (as in `stubJSON`), every field is present — so missing-key crashes are
/// hidden.  These tests use raw JSON strings that mirror actual Rails serializer
/// output, catching mismatches at the service boundary.
///
/// Each test is named after the Rails serializer it validates against.
final class APIContractTests: XCTestCase {

  private let decoder = APIClient.decoder

  // MARK: - ListSerializer

  func testListSerializer_FullResponse() throws {
    let json = """
    {
      "id": 1,
      "name": "Morning Habits",
      "description": "Track daily habits",
      "visibility": "private",
      "color": "orange",
      "list_type": "habit_tracker",
      "user": {"id": 42, "name": "Alice"},
      "role": "owner",
      "tasks_count": 5,
      "parent_tasks_count": 3,
      "completed_tasks_count": 2,
      "overdue_tasks_count": 1,
      "members": [
        {"id": 10, "name": "Alice", "email": "alice@example.com", "role": "owner"},
        {"id": 11, "name": "Bob", "role": "editor"}
      ],
      "tags": [{"id": 1, "name": "Health", "color": "green", "tasks_count": 3}],
      "created_at": "2026-01-01T00:00:00Z",
      "updated_at": "2026-01-15T12:00:00Z"
    }
    """.data(using: .utf8)!

    let list = try decoder.decode(ListDTO.self, from: json)

    XCTAssertEqual(list.id, 1)
    XCTAssertEqual(list.name, "Morning Habits")
    XCTAssertEqual(list.list_type, "habit_tracker")
    XCTAssertEqual(list.user?.id, 42)
    XCTAssertEqual(list.user?.name, "Alice")
    XCTAssertEqual(list.members?.count, 2)
    XCTAssertNil(list.members?[1].email, "Backend omits email for non-owner members")
    XCTAssertEqual(list.members?[1].displayName, "Bob")
    XCTAssertEqual(list.tags?.count, 1)
  }

  func testListSerializer_MinimalResponse() throws {
    // Backend may omit many optional fields
    let json = """
    {
      "id": 1,
      "name": "Test",
      "visibility": "private",
      "tasks_count": 0,
      "created_at": "2026-01-01T00:00:00Z",
      "updated_at": "2026-01-01T00:00:00Z"
    }
    """.data(using: .utf8)!

    let list = try decoder.decode(ListDTO.self, from: json)

    XCTAssertEqual(list.id, 1)
    XCTAssertNil(list.color)
    XCTAssertNil(list.list_type)
    XCTAssertNil(list.user)
    XCTAssertNil(list.role)
    XCTAssertNil(list.members)
    XCTAssertNil(list.tags)
  }

  // MARK: - TaskSerializer

  func testTaskSerializer_FullResponse() throws {
    let json = """
    {
      "id": 42,
      "list_id": 1,
      "list_name": "Daily",
      "color": "blue",
      "title": "Review code",
      "note": "Check PR #123",
      "due_at": "2026-02-17T14:00:00Z",
      "completed_at": null,
      "priority": 3,
      "starred": true,
      "hidden": false,
      "position": 0,
      "status": "active",
      "can_edit": true,
      "can_delete": true,
      "created_at": "2026-02-01T00:00:00Z",
      "updated_at": "2026-02-17T00:00:00Z",
      "tags": [{"id": 1, "name": "Work", "color": "blue"}],
      "reschedule_events": [
        {
          "id": 1,
          "task_id": 42,
          "original_due_at": "2026-02-16T10:00:00Z",
          "new_due_at": "2026-02-17T14:00:00Z",
          "reason": "busy",
          "rescheduled_by": {"id": 42, "name": "Alice"},
          "created_at": "2026-02-16T18:00:00Z"
        }
      ],
      "parent_task_id": null,
      "subtasks": [
        {
          "id": 100,
          "parent_task_id": 42,
          "title": "Sub 1",
          "note": null,
          "status": "pending",
          "completed_at": null,
          "position": 0,
          "created_at": "2026-02-01T00:00:00Z",
          "updated_at": "2026-02-01T00:00:00Z"
        }
      ],
      "creator": {"id": 10, "name": "Bob", "role": "editor"},
      "is_recurring": true,
      "recurrence_pattern": "daily",
      "recurrence_interval": 1,
      "recurrence_days": [1, 2, 3, 4, 5],
      "recurrence_end_date": null,
      "recurrence_count": null,
      "template_id": 5,
      "instance_date": "2026-02-17",
      "instance_number": 3,
      "location_based": false,
      "location_name": null,
      "location_latitude": null,
      "location_longitude": null,
      "location_radius_meters": null,
      "notify_on_arrival": null,
      "notify_on_departure": null,
      "notification_interval_minutes": 30,
      "has_subtasks": true,
      "subtasks_count": 1,
      "subtasks_completed_count": 0,
      "subtask_completion_percentage": 0,
      "overdue": false,
      "minutes_overdue": null,
      "requires_explanation_if_missed": false,
      "missed_reason": null,
      "missed_reason_submitted_at": null
    }
    """.data(using: .utf8)!

    let task = try decoder.decode(TaskDTO.self, from: json)

    XCTAssertEqual(task.id, 42)
    XCTAssertEqual(task.title, "Review code")
    XCTAssertEqual(task.priority, 3)
    XCTAssertTrue(task.starred ?? false)
    XCTAssertEqual(task.creator?.name, "Bob")
    XCTAssertNil(task.creator?.email, "Backend TaskCreatorSerializer omits email")
    XCTAssertEqual(task.creator?.displayName, "Bob")
    XCTAssertEqual(task.subtasks?.count, 1)
    XCTAssertEqual(task.subtasks?.first?.parent_task_id, 42)
    XCTAssertEqual(task.reschedule_events?.count, 1)
    XCTAssertEqual(task.reschedule_events?.first?.rescheduled_by?.name, "Alice")
    XCTAssertEqual(task.is_recurring, true)
    XCTAssertEqual(task.recurrence_days, [1, 2, 3, 4, 5])
    XCTAssertEqual(task.notification_interval_minutes, 30)
    XCTAssertEqual(task.has_subtasks, true)
    XCTAssertEqual(task.subtasks_count, 1)
  }

  func testTaskSerializer_MinimalResponse() throws {
    // Minimal task: only required fields from backend
    let json = """
    {
      "id": 1,
      "list_id": 1,
      "title": "Quick task",
      "created_at": "2026-02-17T00:00:00Z",
      "updated_at": "2026-02-17T00:00:00Z"
    }
    """.data(using: .utf8)!

    let task = try decoder.decode(TaskDTO.self, from: json)

    XCTAssertEqual(task.id, 1)
    XCTAssertEqual(task.title, "Quick task")
    XCTAssertNil(task.due_at)
    XCTAssertNil(task.creator)
    XCTAssertNil(task.subtasks)
    XCTAssertNil(task.is_recurring)
    XCTAssertNil(task.location_based)
    XCTAssertNil(task.has_subtasks)
    XCTAssertNil(task.overdue)
  }

  // MARK: - TodaySerializer

  func testTodaySerializer_FullResponse() throws {
    // Mirrors TodaySerializer output with CodingKeys name mapping
    let json = """
    {
      "overdue": [
        {"id": 1, "list_id": 1, "title": "Overdue", "due_at": "2026-02-16T10:00:00Z",
         "overdue": true, "minutes_overdue": 1440}
      ],
      "has_more_overdue": false,
      "due_today": [
        {"id": 2, "list_id": 1, "title": "Today task", "due_at": "2026-02-17T14:00:00Z"}
      ],
      "completed_today": [
        {"id": 3, "list_id": 1, "title": "Done", "completed_at": "2026-02-17T09:00:00Z"}
      ],
      "stats": {
        "overdue_count": 1,
        "total_due_today": 2,
        "completed_today": 1,
        "remaining_today": 1,
        "completion_percentage": 50
      },
      "streak": {
        "current": 5,
        "longest": 12
      }
    }
    """.data(using: .utf8)!

    let today = try decoder.decode(TodayResponse.self, from: json)

    XCTAssertEqual(today.overdue.count, 1)
    XCTAssertEqual(today.has_more_overdue, false)
    XCTAssertEqual(today.due_today.count, 1)
    XCTAssertEqual(today.completed_today.count, 1)

    // Critical: these map through CodingKeys from backend names
    XCTAssertEqual(today.stats?.overdue_count, 1)
    XCTAssertEqual(today.stats?.due_today_count, 2, "total_due_today → due_today_count via CodingKeys")
    XCTAssertEqual(today.stats?.completed_today_count, 1, "completed_today → completed_today_count via CodingKeys")
    XCTAssertEqual(today.stats?.remaining_today, 1)
    XCTAssertEqual(today.stats?.completion_percentage, 50)

    XCTAssertEqual(today.streak?.current, 5)
    XCTAssertEqual(today.streak?.longest, 12)
  }

  func testTodaySerializer_MinimalResponse() throws {
    let json = """
    {
      "overdue": [],
      "due_today": [],
      "completed_today": []
    }
    """.data(using: .utf8)!

    let today = try decoder.decode(TodayResponse.self, from: json)

    XCTAssertTrue(today.overdue.isEmpty)
    XCTAssertNil(today.has_more_overdue)
    XCTAssertNil(today.stats)
    XCTAssertNil(today.streak)
  }

  // MARK: - SubtaskSerializer (standalone)

  func testSubtaskSerializer_FullResponse() throws {
    let json = """
    {
      "id": 100,
      "parent_task_id": 42,
      "title": "Review tests",
      "note": "Focus on edge cases",
      "status": "completed",
      "completed_at": "2026-02-17T10:00:00Z",
      "position": 2,
      "created_at": "2026-02-01T00:00:00Z",
      "updated_at": "2026-02-17T10:00:00Z"
    }
    """.data(using: .utf8)!

    let subtask = try decoder.decode(SubtaskDTO.self, from: json)

    XCTAssertEqual(subtask.id, 100)
    XCTAssertEqual(subtask.parent_task_id, 42)
    XCTAssertEqual(subtask.title, "Review tests")
    XCTAssertEqual(subtask.note, "Focus on edge cases")
    XCTAssertEqual(subtask.status, "completed")
    XCTAssertNotNil(subtask.completed_at)
    XCTAssertNotNil(subtask.updated_at)
  }

  // MARK: - InviteSerializer

  func testInviteSerializer_FullResponse() throws {
    let json = """
    {
      "invite": {
        "id": 1,
        "code": "ABC123",
        "invite_url": "https://intentia.app/invite/ABC123",
        "role": "editor",
        "uses_count": 3,
        "max_uses": 10,
        "expires_at": "2026-03-01T00:00:00Z",
        "usable": true,
        "created_at": "2026-02-01T00:00:00Z"
      }
    }
    """.data(using: .utf8)!

    let response = try decoder.decode(InviteResponse.self, from: json)
    let invite = response.invite

    XCTAssertEqual(invite.id, 1)
    XCTAssertEqual(invite.code, "ABC123")
    XCTAssertEqual(invite.role, "editor")
    XCTAssertEqual(invite.uses_count, 3)
    XCTAssertEqual(invite.max_uses, 10)
    XCTAssertNotNil(invite.expires_at)
    XCTAssertNotNil(invite.created_at)
  }

  // MARK: - InvitePreviewSerializer

  func testInvitePreviewSerializer_FullResponse() throws {
    let json = """
    {
      "invite": {
        "code": "ABC123",
        "role": "viewer",
        "list": {"id": 1, "name": "Shared Tasks", "color": "blue"},
        "inviter": {"name": "Alice"},
        "usable": true,
        "expired": false,
        "exhausted": false
      }
    }
    """.data(using: .utf8)!

    let response = try decoder.decode(InvitePreviewResponse.self, from: json)
    let preview = response.invite

    XCTAssertEqual(preview.code, "ABC123")
    XCTAssertEqual(preview.listName, "Shared Tasks")
    XCTAssertEqual(preview.inviterName, "Alice")
    XCTAssertTrue(preview.usable)
  }

  func testInvitePreviewSerializer_NullColor() throws {
    // InviteListInfo.color is optional — backend may omit it
    let json = """
    {
      "invite": {
        "code": "XYZ",
        "role": "viewer",
        "list": {"id": 1, "name": "Tasks"},
        "inviter": null,
        "usable": false,
        "expired": true,
        "exhausted": false
      }
    }
    """.data(using: .utf8)!

    let response = try decoder.decode(InvitePreviewResponse.self, from: json)

    XCTAssertNil(response.invite.list.color)
    XCTAssertNil(response.invite.inviterName)
    XCTAssertTrue(response.invite.expired)
  }

  // MARK: - DeviceSerializer

  func testDeviceSerializer_FullResponse() throws {
    let json = """
    {
      "id": 1,
      "platform": "ios",
      "device_name": "iPhone",
      "bundle_id": "com.intentia.app",
      "os_version": "18.0",
      "app_version": "1.0",
      "active": true,
      "last_seen_at": "2026-02-17T12:00:00Z",
      "created_at": "2026-01-01T00:00:00Z",
      "updated_at": "2026-02-17T12:00:00Z"
    }
    """.data(using: .utf8)!

    let device = try decoder.decode(DeviceResponse.self, from: json)

    XCTAssertEqual(device.id, 1)
    XCTAssertEqual(device.platform, "ios")
    XCTAssertEqual(device.device_name, "iPhone")
    XCTAssertEqual(device.active, true)
  }

  func testDeviceSerializer_MinimalResponse() throws {
    // Backend may omit optional fields
    let json = """
    {
      "id": 1,
      "platform": "ios"
    }
    """.data(using: .utf8)!

    let device = try decoder.decode(DeviceResponse.self, from: json)

    XCTAssertEqual(device.id, 1)
    XCTAssertNil(device.device_name)
    XCTAssertNil(device.active)
    XCTAssertNil(device.last_seen_at)
  }

  // MARK: - FriendSerializer

  func testFriendSerializer_FullResponse() throws {
    let json = """
    {"id": 1, "name": "Alice", "email": "alice@example.com"}
    """.data(using: .utf8)!

    let friend = try decoder.decode(FriendDTO.self, from: json)

    XCTAssertEqual(friend.id, 1)
    XCTAssertEqual(friend.name, "Alice")
    XCTAssertEqual(friend.email, "alice@example.com")
  }

  func testFriendSerializer_NullOptionals() throws {
    let json = """
    {"id": 1, "name": null, "email": null}
    """.data(using: .utf8)!

    let friend = try decoder.decode(FriendDTO.self, from: json)

    XCTAssertEqual(friend.id, 1)
    XCTAssertNil(friend.name)
    XCTAssertNil(friend.email)
  }

  // MARK: - MembershipSerializer

  func testMembershipSerializer_FullResponse() throws {
    let json = """
    {
      "id": 1,
      "user": {"id": 10, "email": "user@example.com", "name": "Alice"},
      "role": "editor",
      "created_at": "2026-01-01T00:00:00Z",
      "updated_at": "2026-02-01T00:00:00Z"
    }
    """.data(using: .utf8)!

    let membership = try decoder.decode(MembershipDTO.self, from: json)

    XCTAssertEqual(membership.id, 1)
    XCTAssertEqual(membership.user.name, "Alice")
    XCTAssertEqual(membership.role, "editor")
  }

  // MARK: - RescheduleEventSerializer

  func testRescheduleEventSerializer_FullResponse() throws {
    let json = """
    {
      "id": 1,
      "task_id": 42,
      "original_due_at": "2026-02-16T10:00:00Z",
      "new_due_at": "2026-02-17T14:00:00Z",
      "reason": "meeting conflict",
      "rescheduled_by": {"id": 42, "name": "Alice"},
      "created_at": "2026-02-16T18:00:00Z"
    }
    """.data(using: .utf8)!

    let event = try decoder.decode(RescheduleEventDTO.self, from: json)

    XCTAssertEqual(event.id, 1)
    XCTAssertEqual(event.task_id, 42)
    XCTAssertEqual(event.reason, "meeting conflict")
    XCTAssertEqual(event.previousDueDate, ISO8601DateFormatter().date(from: "2026-02-16T10:00:00Z"))
    XCTAssertEqual(event.rescheduled_by?.id, 42)
    XCTAssertEqual(event.rescheduled_by?.name, "Alice")
  }

  func testRescheduleEventSerializer_MinimalResponse() throws {
    // Backend may omit optional fields
    let json = """
    {
      "id": 1,
      "original_due_at": "2026-02-16T10:00:00Z",
      "new_due_at": "2026-02-17T14:00:00Z",
      "created_at": "2026-02-16T18:00:00Z"
    }
    """.data(using: .utf8)!

    let event = try decoder.decode(RescheduleEventDTO.self, from: json)

    XCTAssertNil(event.task_id, "task_id is optional when embedded in a task")
    XCTAssertNil(event.rescheduled_by)
    XCTAssertNil(event.reason)
    XCTAssertEqual(event.reasonLabel, "Rescheduled")
  }

  // MARK: - TagSerializer

  func testTagSerializer_FullResponse() throws {
    let json = """
    {"id": 1, "name": "Work", "color": "blue", "tasks_count": 5, "created_at": "2026-01-01T00:00:00Z"}
    """.data(using: .utf8)!

    let tag = try decoder.decode(TagDTO.self, from: json)

    XCTAssertEqual(tag.id, 1)
    XCTAssertEqual(tag.name, "Work")
    XCTAssertEqual(tag.color, "blue")
    XCTAssertEqual(tag.tasks_count, 5)
  }

  // MARK: - AcceptInviteResponse

  func testAcceptInviteSerializer_FullResponse() throws {
    let json = """
    {
      "list": {
        "id": 1, "name": "Shared", "visibility": "shared", "color": "blue",
        "tasks_count": 0, "created_at": "2026-01-01T00:00:00Z", "updated_at": "2026-01-01T00:00:00Z"
      },
      "membership": {
        "id": 5, "user": {"id": 10, "email": "new@test.com", "name": "New"},
        "role": "editor", "created_at": "2026-02-17T00:00:00Z"
      }
    }
    """.data(using: .utf8)!

    let response = try decoder.decode(AcceptInviteResponse.self, from: json)

    XCTAssertEqual(response.list.id, 1)
    XCTAssertEqual(response.membership.role, "editor")
  }
}
