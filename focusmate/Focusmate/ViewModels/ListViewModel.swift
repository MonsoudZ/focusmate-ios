import Foundation
import Combine

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
        isLoading = true
        error = nil
        
        do {
            lists = try await listService.fetchLists()
            print("✅ ListViewModel: Loaded \(lists.count) lists")
        } catch {
            self.error = ErrorHandler.shared.handle(error)
            print("❌ ListViewModel: Failed to load lists: \(error)")
        }
        
        isLoading = false
    }
    
    func createList(name: String, description: String?) async {
        isLoading = true
        error = nil
        
        do {
            let newList = try await listService.createList(name: name, description: description)
            lists.append(newList)
            print("✅ ListViewModel: Created list: \(newList.name)")
        } catch {
            self.error = ErrorHandler.shared.handle(error)
            print("❌ ListViewModel: Failed to create list: \(error)")
        }
        
        isLoading = false
    }
    
    func updateList(id: Int, name: String?, description: String?) async {
        isLoading = true
        error = nil
        
        do {
            let updatedList = try await listService.updateList(id: id, name: name, description: description)
            if let index = lists.firstIndex(where: { $0.id == id }) {
                lists[index] = updatedList
            }
            print("✅ ListViewModel: Updated list: \(updatedList.name)")
        } catch {
            self.error = ErrorHandler.shared.handle(error)
            print("❌ ListViewModel: Failed to update list: \(error)")
        }
        
        isLoading = false
    }
    
    func deleteList(id: Int) async {
        isLoading = true
        error = nil
        
        do {
            try await listService.deleteList(id: id)
            lists.removeAll { $0.id == id }
            print("✅ ListViewModel: Deleted list with id: \(id)")
        } catch {
            self.error = ErrorHandler.shared.handle(error)
            print("❌ ListViewModel: Failed to delete list: \(error)")
        }
        
        isLoading = false
    }
    
    func clearError() {
        error = nil
    }
}
