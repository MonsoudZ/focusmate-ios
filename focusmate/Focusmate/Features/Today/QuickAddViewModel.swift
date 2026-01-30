import Foundation

@MainActor
@Observable
final class QuickAddViewModel {
    private let listService: ListService
    private let taskService: TaskService

    var title = ""
    var selectedList: ListDTO?
    var lists: [ListDTO] = []
    var isLoading = false
    var isLoadingLists = true
    var error: FocusmateError?

    var onTaskCreated: (() async -> Void)?

    var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && selectedList != nil
            && !isLoading
    }

    init(listService: ListService, taskService: TaskService) {
        self.listService = listService
        self.taskService = taskService
    }

    func loadLists() async {
        isLoadingLists = true
        do {
            lists = try await listService.fetchLists()
            selectedList = lists.first
        } catch {
            Logger.error("Failed to load lists", error: error, category: .api)
        }
        isLoadingLists = false
    }

    func createTask() async -> Bool {
        guard let list = selectedList else { return false }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }

        isLoading = true
        defer { isLoading = false }

        do {
            let dueDate = Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: Date()) ?? Date()

            _ = try await taskService.createTask(
                listId: list.id,
                title: trimmedTitle,
                note: nil,
                dueAt: dueDate
            )

            HapticManager.success()
            await onTaskCreated?()
            return true
        } catch {
            self.error = ErrorHandler.shared.handle(error, context: "Creating task")
            HapticManager.error()
            return false
        }
    }
}
