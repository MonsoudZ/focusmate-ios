import Foundation

struct SubtaskDTO: Codable, Identifiable, Hashable {
  let id: Int
  let parent_task_id: Int?
  let title: String
  let note: String?
  let status: String?
  let completed_at: String?
  let position: Int?
  let created_at: String?
  let updated_at: String?

  var isCompleted: Bool {
    self.completed_at != nil
  }
}

struct SubtaskResponse: Codable {
  let subtask: SubtaskDTO
}
