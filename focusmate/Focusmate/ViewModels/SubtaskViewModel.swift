import Foundation
import SwiftUI
import Combine

@MainActor
final class SubtaskViewModel: ObservableObject {
  @Published var subtasks: [Subtask] = []
  @Published var isLoading = false
  @Published var error: FocusmateError?

  private let taskId: Int
  private let subtaskService: SubtaskService

  var completedCount: Int {
    subtasks.filter { $0.isCompleted }.count
  }

  var completionPercentage: Int {
    guard !subtasks.isEmpty else { return 0 }
    return Int((Double(completedCount) / Double(subtasks.count)) * 100)
  }

  init(taskId: Int, subtaskService: SubtaskService) {
    self.taskId = taskId
    self.subtaskService = subtaskService
  }

  func loadSubtasks() async {
    isLoading = true
    error = nil

    do {
      subtasks = try await subtaskService.fetchSubtasks(taskId: taskId)
      #if DEBUG
      print("✅ SubtaskViewModel: Loaded \(subtasks.count) subtasks for task \(taskId)")
      #endif
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      #if DEBUG
      print("❌ SubtaskViewModel: Failed to load subtasks: \(error)")
      #endif
    }

    isLoading = false
  }

  func createSubtask(title: String, description: String?) async {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty else {
      error = .custom("VALIDATION_ERROR", "Subtask title is required")
      return
    }

    guard trimmedTitle.count <= 255 else {
      error = .custom("VALIDATION_ERROR", "Subtask title must be 255 characters or less")
      return
    }

    isLoading = true
    error = nil

    do {
      let newSubtask = try await subtaskService.createSubtask(
        taskId: taskId,
        title: trimmedTitle,
        description: description
      )
      subtasks.append(newSubtask)
      // Sort by position
      subtasks.sort { $0.position < $1.position }
      #if DEBUG
      print("✅ SubtaskViewModel: Created subtask: \(newSubtask.title)")
      #endif
    } catch let apiError as APIError {
      switch apiError {
      case let .badStatus(422, message, _):
        error = .custom("VALIDATION_ERROR", message ?? "Invalid subtask data")
      case .unauthorized:
        error = .unauthorized("You are not authorized to create subtasks for this task")
      default:
        error = ErrorHandler.shared.handle(apiError)
      }
      #if DEBUG
      print("❌ SubtaskViewModel: Failed to create subtask: \(apiError)")
      #endif
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      #if DEBUG
      print("❌ SubtaskViewModel: Failed to create subtask: \(error)")
      #endif
    }

    isLoading = false
  }

  func toggleSubtask(id: Int) async {
    guard let index = subtasks.firstIndex(where: { $0.id == id }) else { return }
    let currentStatus = subtasks[index].isCompleted

    error = nil

    do {
      let updatedSubtask = try await subtaskService.completeSubtask(
        id: id,
        completed: !currentStatus
      )
      subtasks[index] = updatedSubtask
      #if DEBUG
      print("✅ SubtaskViewModel: Toggled subtask \(id) to \(!currentStatus)")
      #endif
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      #if DEBUG
      print("❌ SubtaskViewModel: Failed to toggle subtask: \(error)")
      #endif
    }
  }

  func deleteSubtask(id: Int) async {
    error = nil

    do {
      try await subtaskService.deleteSubtask(id: id)
      subtasks.removeAll { $0.id == id }
      #if DEBUG
      print("✅ SubtaskViewModel: Deleted subtask \(id)")
      #endif
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      #if DEBUG
      print("❌ SubtaskViewModel: Failed to delete subtask: \(error)")
      #endif
    }
  }

  func reorderSubtasks(from source: IndexSet, to destination: Int) async {
    // Move locally first for immediate UI feedback
    var updatedSubtasks = subtasks
    updatedSubtasks.move(fromOffsets: source, toOffset: destination)
    subtasks = updatedSubtasks

    // Update positions on server
    let subtaskIds = subtasks.map { $0.id }

    do {
      try await subtaskService.reorderSubtasks(taskId: taskId, subtaskIds: subtaskIds)
      #if DEBUG
      print("✅ SubtaskViewModel: Reordered subtasks")
      #endif
      // Reload to get correct positions from server
      await loadSubtasks()
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      #if DEBUG
      print("❌ SubtaskViewModel: Failed to reorder subtasks: \(error)")
      #endif
      // Reload to revert to server state
      await loadSubtasks()
    }
  }

  func clearError() {
    error = nil
  }
}
