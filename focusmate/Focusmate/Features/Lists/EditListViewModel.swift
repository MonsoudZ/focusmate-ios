import Foundation

@MainActor
@Observable
final class EditListViewModel {
    var name: String
    var description: String
    var selectedColor: String
    var isLoading = false
    var error: FocusmateError?

    private let list: ListDTO
    private let listService: ListService

    init(list: ListDTO, listService: ListService) {
        self.list = list
        self.listService = listService
        self.name = list.name
        self.description = list.description ?? ""
        self.selectedColor = list.color ?? "blue"
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
                color: selectedColor
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
