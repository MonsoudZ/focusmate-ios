import Combine
import Foundation

/// Represents a change to a subtask that consumers can react to
struct SubtaskChange {
    enum ChangeType {
        case completed(SubtaskDTO)
        case reopened(SubtaskDTO)
        case created(SubtaskDTO)
        case updated(SubtaskDTO)
        case deleted(subtaskId: Int)
    }

    let type: ChangeType
    let parentTaskId: Int
    let listId: Int
}

/// Centralized manager for subtask operations.
/// Publishes changes so ViewModels can react and refresh their data.
@MainActor
final class SubtaskManager {
    private let taskService: TaskService

    /// Publisher that emits whenever a subtask changes
    let changePublisher = PassthroughSubject<SubtaskChange, Never>()

    init(taskService: TaskService) {
        self.taskService = taskService
    }

    // MARK: - Subtask Operations

    func toggleComplete(subtask: SubtaskDTO, parentTask: TaskDTO) async throws -> SubtaskDTO {
        let updated: SubtaskDTO
        let changeType: SubtaskChange.ChangeType

        if subtask.isCompleted {
            updated = try await taskService.reopenSubtask(
                listId: parentTask.list_id,
                parentTaskId: parentTask.id,
                subtaskId: subtask.id
            )
            changeType = .reopened(updated)
        } else {
            updated = try await taskService.completeSubtask(
                listId: parentTask.list_id,
                parentTaskId: parentTask.id,
                subtaskId: subtask.id
            )
            changeType = .completed(updated)
        }

        HapticManager.light()

        changePublisher.send(SubtaskChange(
            type: changeType,
            parentTaskId: parentTask.id,
            listId: parentTask.list_id
        ))

        return updated
    }

    func delete(subtask: SubtaskDTO, parentTask: TaskDTO) async throws {
        try await taskService.deleteSubtask(
            listId: parentTask.list_id,
            parentTaskId: parentTask.id,
            subtaskId: subtask.id
        )

        HapticManager.medium()

        changePublisher.send(SubtaskChange(
            type: .deleted(subtaskId: subtask.id),
            parentTaskId: parentTask.id,
            listId: parentTask.list_id
        ))
    }

    func create(parentTask: TaskDTO, title: String) async throws -> SubtaskDTO {
        let subtask = try await taskService.createSubtask(
            listId: parentTask.list_id,
            parentTaskId: parentTask.id,
            title: title
        )

        HapticManager.success()

        changePublisher.send(SubtaskChange(
            type: .created(subtask),
            parentTaskId: parentTask.id,
            listId: parentTask.list_id
        ))

        return subtask
    }

    func update(subtask: SubtaskDTO, parentTask: TaskDTO, title: String) async throws -> SubtaskDTO {
        let updated = try await taskService.updateSubtask(
            listId: parentTask.list_id,
            parentTaskId: parentTask.id,
            subtaskId: subtask.id,
            title: title
        )

        HapticManager.success()

        changePublisher.send(SubtaskChange(
            type: .updated(updated),
            parentTaskId: parentTask.id,
            listId: parentTask.list_id
        ))

        return updated
    }
}
