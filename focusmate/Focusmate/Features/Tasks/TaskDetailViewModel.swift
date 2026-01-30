import Foundation

@MainActor
@Observable
final class TaskDetailViewModel {
    var showingDeleteConfirmation = false
    var error: FocusmateError?

    let task: TaskDTO
    let listName: String
    let listId: Int
    let onComplete: () async -> Void
    let onDelete: () async -> Void
    let onUpdate: () async -> Void
    let taskService: TaskService
    let tagService: TagService

    init(
        task: TaskDTO,
        listName: String,
        listId: Int,
        taskService: TaskService,
        tagService: TagService,
        onComplete: @escaping () async -> Void,
        onDelete: @escaping () async -> Void,
        onUpdate: @escaping () async -> Void
    ) {
        self.task = task
        self.listName = listName
        self.listId = listId
        self.taskService = taskService
        self.tagService = tagService
        self.onComplete = onComplete
        self.onDelete = onDelete
        self.onUpdate = onUpdate
    }

    var isOverdue: Bool {
        task.isActuallyOverdue
    }
}
