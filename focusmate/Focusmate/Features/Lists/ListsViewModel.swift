import Foundation

@MainActor
@Observable
final class ListsViewModel {
    let listService: ListService
    let taskService: TaskService
    let tagService: TagService
    let inviteService: InviteService
    let friendService: FriendService

    var lists: [ListDTO] = []
    var isLoading = false
    var error: FocusmateError?
    var showingDeleteConfirmation = false
    var listToDelete: ListDTO?

    init(listService: ListService, taskService: TaskService, tagService: TagService, inviteService: InviteService, friendService: FriendService) {
        self.listService = listService
        self.taskService = taskService
        self.tagService = tagService
        self.inviteService = inviteService
        self.friendService = friendService
    }

    func loadLists() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            lists = try await listService.fetchLists()
        } catch let err as FocusmateError {
            error = err
        } catch {
            self.error = ErrorHandler.shared.handle(error)
        }
    }

    func deleteList(_ list: ListDTO) async {
        let originalLists = lists
        lists.removeAll { $0.id == list.id }

        do {
            try await listService.deleteList(id: list.id)
        } catch {
            lists = originalLists
            self.error = ErrorHandler.shared.handle(error, context: "Delete List")
        }
    }
}
