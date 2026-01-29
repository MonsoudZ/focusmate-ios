import Combine
import Foundation

@MainActor
final class ListsViewModel: ObservableObject {
    let listService: ListService
    let taskService: TaskService
    let tagService: TagService
    let inviteService: InviteService

    @Published var lists: [ListDTO] = []
    @Published var isLoading = false
    @Published var error: FocusmateError?
    @Published var showingCreateList = false
    @Published var showingSearch = false
    @Published var showingDeleteConfirmation = false
    @Published var listToDelete: ListDTO?
    @Published var selectedList: ListDTO?

    init(listService: ListService, taskService: TaskService, tagService: TagService, inviteService: InviteService) {
        self.listService = listService
        self.taskService = taskService
        self.tagService = tagService
        self.inviteService = inviteService
    }

    func loadLists() async {
        isLoading = true
        error = nil

        do {
            lists = try await listService.fetchLists()
        } catch let err as FocusmateError {
            error = err
        } catch {
            self.error = ErrorHandler.shared.handle(error)
        }

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
