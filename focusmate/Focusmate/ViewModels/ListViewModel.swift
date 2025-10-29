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
      // Use the new API layer
      let authSession = AuthSession()
      let apiClient = NewAPIClient(auth: authSession)
      let listsRepo = ListsRepo(api: apiClient)
      let page: Page<ListDTO> = try await listsRepo.index()
      
      self.lists = page.data
      print("✅ ListViewModel: Loaded \(self.lists.count) lists from API")
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      print("❌ ListViewModel: Failed to load lists: \(error)")
    }

    self.isLoading = false
  }

  func createList(name: String, description: String?) async {
    self.isLoading = true
    self.error = nil

    do {
      // Use the new API layer
      let authSession = AuthSession()
      let apiClient = NewAPIClient(auth: authSession)
      let listsRepo = ListsRepo(api: apiClient)
      let newList = try await listsRepo.create(title: name, visibility: "private")
      
      self.lists.append(newList)
      print("✅ ListViewModel: Created list: \(newList.title)")
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      print("❌ ListViewModel: Failed to create list: \(error)")
    }

    self.isLoading = false
  }

  func updateList(id: Int, name: String?, description: String?) async {
    self.isLoading = true
    self.error = nil

    do {
      let updatedList = try await listService.updateList(id: id, name: name, description: description)
      if let index = lists.firstIndex(where: { $0.id == String(id) }) {
        self.lists[index] = updatedList
      }
      print("✅ ListViewModel: Updated list: \(updatedList.title)")
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      print("❌ ListViewModel: Failed to update list: \(error)")
    }

    self.isLoading = false
  }

  func deleteList(id: Int) async {
    self.isLoading = true
    self.error = nil

    do {
      try await self.listService.deleteList(id: id)
      self.lists.removeAll { $0.id == String(id) }
      print("✅ ListViewModel: Deleted list with id: \(id)")
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      print("❌ ListViewModel: Failed to delete list: \(error)")
    }

    self.isLoading = false
  }

  func clearError() {
    self.error = nil
  }
}
