import Combine
import Foundation

@MainActor
final class ListViewModel: ObservableObject {
  @Published var lists: [ListDTO] = []
  @Published var isLoading = false
  @Published var error: FocusmateError?

  private let listService: ListService
  private var cancellables = Set<AnyCancellable>()

  init(listService: ListService) {
    self.listService = listService
  }

  func loadLists() async {
    self.isLoading = true
    self.error = nil

    do {
      // Use the injected authenticated listService
      self.lists = try await listService.fetchLists()
      Logger.info("ListViewModel: Loaded \(self.lists.count) lists from API", category: .database)
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      Logger.error("ListViewModel: Failed to load lists: \(error)", category: .database)
    }

    self.isLoading = false
  }

  func createList(name: String, description: String?) async {
    self.isLoading = true
    self.error = nil

    do {
      // Use the injected authenticated listService
      let newList = try await listService.createList(name: name, description: description)

      self.lists.append(newList)
      Logger.info("ListViewModel: Created list: \(newList.title)", category: .database)
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      Logger.error("ListViewModel: Failed to create list: \(error)", category: .database)
    }

    self.isLoading = false
  }

  func updateList(id: Int, name: String?, description: String?) async {
    self.isLoading = true
    self.error = nil

    do {
      let updatedList = try await listService.updateList(id: id, name: name, description: description)
      if let index = lists.firstIndex(where: { $0.id == id }) {
        self.lists[index] = updatedList
      }
      Logger.info("ListViewModel: Updated list: \(updatedList.title)", category: .database)
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      Logger.error("ListViewModel: Failed to update list: \(error)", category: .database)
    }

    self.isLoading = false
  }

  func deleteList(id: Int) async {
    self.isLoading = true
    self.error = nil

    do {
      try await self.listService.deleteList(id: id)
      self.lists.removeAll { $0.id == id }
      Logger.info("ListViewModel: Deleted list with id: \(id)", category: .database)
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      Logger.error("ListViewModel: Failed to delete list: \(error)", category: .database)
    }

    self.isLoading = false
  }

  func clearError() {
    self.error = nil
  }
}
