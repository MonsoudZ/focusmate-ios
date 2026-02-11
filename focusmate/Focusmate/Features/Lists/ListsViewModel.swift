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

    private var loadVersion = 0

    /// Load lists with version counter to discard stale responses.
    ///
    /// `.task` and `.refreshable` can both trigger `loadLists()` concurrently.
    /// Without protection, two overlapping calls race at the `await` point.
    /// If the older response arrives second, it overwrites the fresher data.
    /// The version counter ensures only the most recent call's result is applied.
    func loadLists() async {
        loadVersion += 1
        let myVersion = loadVersion

        isLoading = lists.isEmpty
        error = nil

        do {
            let result = try await listService.fetchLists()
            guard myVersion == loadVersion else { return }
            lists = result
        } catch let err as FocusmateError {
            guard myVersion == loadVersion else { return }
            error = err
        } catch {
            guard myVersion == loadVersion else { return }
            self.error = ErrorHandler.shared.handle(error)
        }

        guard myVersion == loadVersion else { return }
        isLoading = false
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
