import Foundation

// MARK: - Task Service Request/Response Models

//
// Design concept: These are **Data Transfer Objects (DTOs)** - they exist solely
// to serialize/deserialize data for the API boundary. They're intentionally
// separate from domain models to allow the API contract to evolve independently.
// This is the **Anti-Corruption Layer** pattern from Domain-Driven Design.

// MARK: - Response Models

struct NudgeResponse: Codable {
  let message: String
}

// MARK: - Task Request Models

struct CreateTaskRequest: Encodable {
  let task: TaskData
  struct TaskData: Encodable {
    let title: String
    let note: String?
    let due_at: String?
    let color: String?
    let priority: Int
    let starred: Bool
    let tag_ids: [Int]?
    let is_recurring: Bool?
    let recurrence_pattern: String?
    let recurrence_interval: Int?
    let recurrence_days: [Int]?
    let recurrence_end_date: String?
    let recurrence_count: Int?
    let parent_task_id: Int?
  }
}

struct UpdateTaskRequest: Encodable {
  let task: TaskData
  struct TaskData: Encodable {
    let title: String?
    let note: String?
    let due_at: String?
    let color: String?
    let priority: Int?
    let starred: Bool?
    let hidden: Bool?
    let tag_ids: [Int]?
  }
}

struct CompleteTaskRequest: Encodable {
  let missed_reason: String
}

struct RescheduleTaskRequest: Encodable {
  let new_due_at: String
  let reason: String
}

struct ReorderTasksRequest: Encodable {
  let tasks: [ReorderTask]
}

struct ReorderTask: Encodable {
  let id: Int
  let position: Int
}

// MARK: - Subtask Request Models

struct CreateSubtaskRequest: Encodable {
  let subtask: SubtaskData
  struct SubtaskData: Encodable {
    let title: String
  }
}

struct UpdateSubtaskRequest: Encodable {
  let subtask: SubtaskData
  struct SubtaskData: Encodable {
    let title: String
  }
}
