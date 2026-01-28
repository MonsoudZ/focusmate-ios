import Foundation

@MainActor
@Observable
final class CreateListViewModel {
    var name = ""
    var description = ""
    var selectedColor = "blue"
    var isLoading = false
    var error: FocusmateError?

    private let listService: ListService

    init(listService: ListService) {
        self.listService = listService
    }

    func createList() async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await listService.createList(
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
            self.error = .custom("CREATE_ERROR", error.localizedDescription)
            HapticManager.error()
        }
        return false
    }
}
