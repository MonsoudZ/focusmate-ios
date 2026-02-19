import Foundation

@MainActor
@Observable
final class CreateListViewModel {
  var name = ""
  var description = ""
  var selectedColor = "blue"
  var selectedTagIds: Set<Int> = []
  var availableTags: [TagDTO] = []
  var isLoading = false
  var error: FocusmateError?

  private let listService: ListService
  let tagService: TagService

  init(listService: ListService, tagService: TagService) {
    self.listService = listService
    self.tagService = tagService
  }

  func loadTags() async {
    do {
      self.availableTags = try await self.tagService.fetchTags()
    } catch {
      Logger.error("Failed to load tags", error: error, category: .api)
    }
  }

  func createList() async -> Bool {
    let trimmedName = self.name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else { return false }

    self.isLoading = true
    defer { isLoading = false }

    do {
      _ = try await self.listService.createList(
        name: trimmedName,
        description: self.description.isEmpty ? nil : self.description,
        color: self.selectedColor,
        tagIds: Array(self.selectedTagIds)
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
