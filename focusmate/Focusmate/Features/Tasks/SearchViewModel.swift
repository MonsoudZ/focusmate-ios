import Foundation

@MainActor
@Observable
final class SearchViewModel {
    var query = ""
    var results: [TaskDTO] = []
    var isSearching = false
    var hasSearched = false
    var error: FocusmateError?
    var lists: [Int: ListDTO] = [:]

    let taskService: TaskService
    let listService: ListService
    private let initialQuery: String

    init(taskService: TaskService, listService: ListService, initialQuery: String = "") {
        self.taskService = taskService
        self.listService = listService
        self.initialQuery = initialQuery
        self.query = initialQuery
    }

    func searchIfNeeded() async {
        if !initialQuery.isEmpty && !hasSearched {
            await search()
        }
    }

    var groupedResults: [(listId: Int, tasks: [TaskDTO])] {
        let grouped = Dictionary(grouping: results) { $0.list_id }
        return grouped.map { (listId: $0.key, tasks: $0.value) }
            .sorted { $0.listId < $1.listId }
    }

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // API limit: max 255 characters
        let searchQuery = String(trimmed.prefix(255))

        isSearching = true
        hasSearched = true
        error = nil  // Reset error before new search

        do {
            results = try await taskService.searchTasks(query: searchQuery)
            await loadListsForResults()
        } catch let err as FocusmateError {
            error = err
            HapticManager.error()
        } catch {
            self.error = ErrorHandler.shared.handle(error, context: "Searching tasks")
            HapticManager.error()
        }

        isSearching = false
    }

    func clearSearch() {
        query = ""
        results = []
        hasSearched = false
    }

    private func loadListsForResults() async {
        let listIds = Set(results.map { $0.list_id })

        do {
            let allLists = try await listService.fetchLists()
            for list in allLists {
                if listIds.contains(list.id) {
                    lists[list.id] = list
                }
            }
        } catch {
            Logger.error("Failed to load lists for search results: \(error)", category: .api)
        }
    }
}
