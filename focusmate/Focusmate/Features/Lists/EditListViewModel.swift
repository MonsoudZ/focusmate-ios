import Foundation

@MainActor
@Observable
final class EditListViewModel {
    var name: String
    var description: String
    var selectedColor: String
    var selectedTagIds: Set<Int>
    var availableTags: [TagDTO] = []
    var isLoading = false
    var error: FocusmateError?

    private let list: ListDTO
    private let listService: ListService
    let tagService: TagService

    init(list: ListDTO, listService: ListService, tagService: TagService) {
        self.list = list
        self.listService = listService
        self.tagService = tagService
        self.name = list.name
        self.description = list.description ?? ""
        self.selectedColor = list.color ?? "blue"
        self.selectedTagIds = Set((list.tags ?? []).map { $0.id })
    }

    func loadTags() async {
        do {
            availableTags = try await tagService.fetchTags()
        } catch {
            Logger.error("Failed to load tags", error: error, category: .api)
        }
    }

    func updateList() async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await listService.updateList(
                id: list.id,
                name: trimmedName,
                description: description.isEmpty ? nil : description,
                color: selectedColor,
                tagIds: Array(selectedTagIds)
            )
            HapticManager.success()
            return true
        } catch let err as FocusmateError {
            error = err
            HapticManager.error()
        } catch {
            self.error = .custom("UPDATE_ERROR", error.localizedDescription)
            HapticManager.error()
        }
        return false
    }
}
