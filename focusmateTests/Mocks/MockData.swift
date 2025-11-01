import Foundation
@testable import focusmate

/// Test fixtures and mock data
enum MockData {
  // MARK: - Users

  static let mockUser = UserDTO(
    id: 1,
    email: "test@example.com",
    name: "Test User",
    role: "client",
    timezone: "America/New_York"
  )

  static let mockCoach = UserDTO(
    id: 2,
    email: "coach@example.com",
    name: "Test Coach",
    role: "coach",
    timezone: "America/Los_Angeles"
  )

  static let mockUserProfile = UserProfile(
    id: 1,
    email: "test@example.com",
    name: "Test User",
    role: "client",
    timezone: "America/New_York",
    accessibleListsCount: 5,
    createdAt: "2025-01-01T00:00:00Z"
  )

  // MARK: - Lists

  static let mockList = ListDTO(
    id: 1,
    name: "Test List",
    description: "A test list",
    visibility: "private",
    user_id: 1,
    deleted_at: nil,
    created_at: "2025-01-01T00:00:00Z",
    updated_at: "2025-01-01T00:00:00Z"
  )

  static let mockLists = [
    mockList,
    ListDTO(
      id: 2,
      name: "Another List",
      description: nil,
      visibility: "shared",
      user_id: 1,
      deleted_at: nil,
      created_at: "2025-01-01T00:00:00Z",
      updated_at: "2025-01-01T00:00:00Z"
    )
  ]

  // MARK: - Items

  static let mockItem = Item(
    id: 1,
    list_id: 1,
    title: "Test Task",
    description: "A test task",
    due_at: "2025-12-31T23:59:59Z",
    completed_at: nil,
    priority: 2,
    can_be_snoozed: true,
    notification_interval_minutes: 15,
    requires_explanation_if_missed: false,
    overdue: false,
    minutes_overdue: 0,
    requires_explanation: false,
    is_recurring: false,
    recurrence_pattern: nil,
    recurrence_interval: 1,
    recurrence_days: nil,
    location_based: false,
    location_name: nil,
    location_latitude: nil,
    location_longitude: nil,
    location_radius_meters: 100,
    notify_on_arrival: false,
    notify_on_departure: false,
    missed_reason: nil,
    missed_reason_submitted_at: nil,
    missed_reason_reviewed_at: nil,
    creator: mockUser,
    created_by_coach: false,
    can_edit: true,
    can_delete: true,
    can_complete: true,
    is_visible: true,
    escalation: nil,
    has_subtasks: false,
    subtasks_count: 0,
    subtasks_completed_count: 0,
    subtask_completion_percentage: 0,
    created_at: "2025-01-01T00:00:00Z",
    updated_at: "2025-01-01T00:00:00Z"
  )

  static let mockCompletedItem = Item(
    id: 2,
    list_id: 1,
    title: "Completed Task",
    description: nil,
    due_at: "2025-01-15T12:00:00Z",
    completed_at: "2025-01-15T11:30:00Z",
    priority: 1,
    can_be_snoozed: true,
    notification_interval_minutes: 15,
    requires_explanation_if_missed: false,
    overdue: false,
    minutes_overdue: 0,
    requires_explanation: false,
    is_recurring: false,
    recurrence_pattern: nil,
    recurrence_interval: 1,
    recurrence_days: nil,
    location_based: false,
    location_name: nil,
    location_latitude: nil,
    location_longitude: nil,
    location_radius_meters: 100,
    notify_on_arrival: false,
    notify_on_departure: false,
    missed_reason: nil,
    missed_reason_submitted_at: nil,
    missed_reason_reviewed_at: nil,
    creator: mockUser,
    created_by_coach: false,
    can_edit: true,
    can_delete: true,
    can_complete: true,
    is_visible: true,
    escalation: nil,
    has_subtasks: false,
    subtasks_count: 0,
    subtasks_completed_count: 0,
    subtask_completion_percentage: 0,
    created_at: "2025-01-01T00:00:00Z",
    updated_at: "2025-01-15T11:30:00Z"
  )

  static let mockRecurringItem = Item(
    id: 3,
    list_id: 1,
    title: "Weekly Meeting",
    description: "Recurring weekly meeting",
    due_at: "2025-02-03T10:00:00Z",
    completed_at: nil,
    priority: 2,
    can_be_snoozed: false,
    notification_interval_minutes: 30,
    requires_explanation_if_missed: true,
    overdue: false,
    minutes_overdue: 0,
    requires_explanation: false,
    is_recurring: true,
    recurrence_pattern: "weekly",
    recurrence_interval: 1,
    recurrence_days: [1, 3, 5],
    location_based: false,
    location_name: nil,
    location_latitude: nil,
    location_longitude: nil,
    location_radius_meters: 100,
    notify_on_arrival: false,
    notify_on_departure: false,
    missed_reason: nil,
    missed_reason_submitted_at: nil,
    missed_reason_reviewed_at: nil,
    creator: mockCoach,
    created_by_coach: true,
    can_edit: false,
    can_delete: false,
    can_complete: true,
    is_visible: true,
    escalation: nil,
    has_subtasks: false,
    subtasks_count: 0,
    subtasks_completed_count: 0,
    subtask_completion_percentage: 0,
    created_at: "2025-01-01T00:00:00Z",
    updated_at: "2025-01-01T00:00:00Z"
  )

  static let mockLocationItem = Item(
    id: 4,
    list_id: 1,
    title: "Gym Workout",
    description: "Workout at the gym",
    due_at: nil,
    completed_at: nil,
    priority: 1,
    can_be_snoozed: true,
    notification_interval_minutes: 15,
    requires_explanation_if_missed: false,
    overdue: false,
    minutes_overdue: 0,
    requires_explanation: false,
    is_recurring: false,
    recurrence_pattern: nil,
    recurrence_interval: 1,
    recurrence_days: nil,
    location_based: true,
    location_name: "Local Gym",
    location_latitude: 37.7749,
    location_longitude: -122.4194,
    location_radius_meters: 200,
    notify_on_arrival: true,
    notify_on_departure: false,
    missed_reason: nil,
    missed_reason_submitted_at: nil,
    missed_reason_reviewed_at: nil,
    creator: mockUser,
    created_by_coach: false,
    can_edit: true,
    can_delete: true,
    can_complete: true,
    is_visible: true,
    escalation: nil,
    has_subtasks: false,
    subtasks_count: 0,
    subtasks_completed_count: 0,
    subtask_completion_percentage: 0,
    created_at: "2025-01-01T00:00:00Z",
    updated_at: "2025-01-01T00:00:00Z"
  )

  static let mockItems = [mockItem, mockCompletedItem, mockRecurringItem, mockLocationItem]

  // MARK: - Subtasks

  static let mockSubtask = Subtask(
    id: 1,
    task_id: 1,
    title: "Subtask 1",
    description: "First subtask",
    completed_at: nil,
    position: 0,
    created_at: "2025-01-01T00:00:00Z",
    updated_at: "2025-01-01T00:00:00Z"
  )

  static let mockSubtasks = [
    mockSubtask,
    Subtask(
      id: 2,
      task_id: 1,
      title: "Subtask 2",
      description: nil,
      completed_at: "2025-01-02T10:00:00Z",
      position: 1,
      created_at: "2025-01-01T00:00:00Z",
      updated_at: "2025-01-02T10:00:00Z"
    )
  ]

  // MARK: - Responses

  static let mockItemsResponse = ItemsResponse(
    tasks: mockItems,
    tombstones: [],
    pagination: ItemsResponse.Pagination(
      page: 1,
      per_page: 20,
      total: 4,
      total_pages: 1
    )
  )

  // MARK: - Errors

  static let mockNetworkError = NSError(
    domain: NSURLErrorDomain,
    code: NSURLErrorNotConnectedToInternet,
    userInfo: [NSLocalizedDescriptionKey: "No internet connection"]
  )

  static let mockAPIError = APIError.badStatus(422, "Validation failed", nil)
}
