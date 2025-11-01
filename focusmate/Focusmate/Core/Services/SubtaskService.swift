import Foundation
import SwiftData

final class SubtaskService {
  private let apiClient: APIClient
  private let swiftDataManager: SwiftDataManager

  init(apiClient: APIClient, swiftDataManager: SwiftDataManager) {
    self.apiClient = apiClient
    self.swiftDataManager = swiftDataManager
  }

  // MARK: - Subtask Management

  func fetchSubtasks(taskId: Int) async throws -> [Subtask] {
    let response: SubtasksResponse = try await apiClient.request(
      "GET",
      "tasks/\(taskId)/subtasks",
      body: nil as String?
    )
    return response.subtasks
  }

  func createSubtask(
    taskId: Int,
    title: String,
    description: String?
  ) async throws -> Subtask {
    let request = CreateSubtaskRequest(
      title: title,
      description: description
    )

    do {
      let jsonData = try JSONEncoder().encode(request)
      if let jsonString = String(data: jsonData, encoding: .utf8) {
        print("🔍 SubtaskService: Sending request payload: \(jsonString)")
      }
    } catch {
      print("❌ SubtaskService: Failed to encode request: \(error)")
    }

    let subtask: Subtask = try await apiClient.request(
      "POST",
      "tasks/\(taskId)/subtasks",
      body: request
    )
    print("✅ SubtaskService: Successfully created subtask: \(subtask.title)")
    return subtask
  }

  func updateSubtask(
    id: Int,
    title: String?,
    description: String?,
    completed: Bool?
  ) async throws -> Subtask {
    let request = UpdateSubtaskRequest(
      title: title,
      description: description,
      completed: completed
    )

    do {
      let jsonData = try JSONEncoder().encode(request)
      if let jsonString = String(data: jsonData, encoding: .utf8) {
        print("🔍 SubtaskService: Sending update request for subtask \(id): \(jsonString)")
      }
    } catch {
      print("❌ SubtaskService: Failed to encode update request: \(error)")
    }

    let subtask: Subtask = try await apiClient.request(
      "PUT",
      "subtasks/\(id)",
      body: request
    )
    print("✅ SubtaskService: Successfully updated subtask: \(subtask.title)")
    return subtask
  }

  func deleteSubtask(id: Int) async throws {
    _ = try await apiClient.request(
      "DELETE",
      "subtasks/\(id)",
      body: nil as String?
    ) as EmptyResponse
    print("✅ SubtaskService: Successfully deleted subtask \(id)")
  }

  func reorderSubtasks(taskId: Int, subtaskIds: [Int]) async throws {
    let request = ReorderSubtasksRequest(subtaskIds: subtaskIds)

    _ = try await apiClient.request(
      "PATCH",
      "tasks/\(taskId)/subtasks/reorder",
      body: request
    ) as EmptyResponse
    print("✅ SubtaskService: Successfully reordered subtasks for task \(taskId)")
  }

  func completeSubtask(id: Int, completed: Bool) async throws -> Subtask {
    let request = CompleteSubtaskRequest(completed: completed)

    let subtask: Subtask = try await apiClient.request(
      "POST",
      "subtasks/\(id)/complete",
      body: request
    )
    print("✅ SubtaskService: Completed subtask \(id) - status: \(completed)")
    return subtask
  }

  // MARK: - Request Models

  struct CreateSubtaskRequest: Codable {
    let title: String
    let description: String?
  }

  struct UpdateSubtaskRequest: Codable {
    let title: String?
    let description: String?
    let completed: Bool?
  }

  struct CompleteSubtaskRequest: Codable {
    let completed: Bool
  }

  struct ReorderSubtasksRequest: Codable {
    let subtaskIds: [Int]

    enum CodingKeys: String, CodingKey {
      case subtaskIds = "subtask_ids"
    }
  }
}
