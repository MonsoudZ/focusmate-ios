import Foundation
import Combine

@MainActor
final class ItemViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var error: FocusmateError?
    @Published var selectedItem: Item?
    
    private let itemService: ItemService
    private var cancellables = Set<AnyCancellable>()
    
    init(itemService: ItemService) {
        self.itemService = itemService
    }
    
    func loadItems(listId: Int) async {
        isLoading = true
        error = nil
        
        do {
            items = try await itemService.fetchItems(listId: listId)
            print("✅ ItemViewModel: Loaded \(items.count) items for list \(listId)")
        } catch {
            self.error = ErrorHandler.shared.handle(error)
            print("❌ ItemViewModel: Failed to load items: \(error)")
        }
        
        isLoading = false
    }
    
    func createItem(listId: Int, name: String, description: String?, dueDate: Date?) async {
        isLoading = true
        error = nil
        
        do {
            let newItem = try await itemService.createItem(
                listId: listId,
                name: name,
                description: description,
                dueDate: dueDate
            )
            items.append(newItem)
            print("✅ ItemViewModel: Created item: \(newItem.title)")
        } catch {
            self.error = ErrorHandler.shared.handle(error)
            print("❌ ItemViewModel: Failed to create item: \(error)")
        }
        
        isLoading = false
    }
    
    func updateItem(id: Int, name: String?, description: String?, completed: Bool?, dueDate: Date?) async {
        isLoading = true
        error = nil
        
        do {
            let updatedItem = try await itemService.updateItem(
                id: id,
                name: name,
                description: description,
                completed: completed,
                dueDate: dueDate
            )
            if let index = items.firstIndex(where: { $0.id == id }) {
                items[index] = updatedItem
            }
            print("✅ ItemViewModel: Updated item: \(updatedItem.title)")
        } catch {
            self.error = ErrorHandler.shared.handle(error)
            print("❌ ItemViewModel: Failed to update item: \(error)")
        }
        
        isLoading = false
    }
    
    func deleteItem(id: Int) async {
        isLoading = true
        error = nil
        
        do {
            try await itemService.deleteItem(id: id)
            items.removeAll { $0.id == id }
            print("✅ ItemViewModel: Deleted item with id: \(id)")
        } catch {
            self.error = ErrorHandler.shared.handle(error)
            print("❌ ItemViewModel: Failed to delete item: \(error)")
        }
        
        isLoading = false
    }
    
    func completeItem(id: Int, completed: Bool, completionNotes: String?) async {
        isLoading = true
        error = nil
        
        do {
            let updatedItem = try await itemService.completeItem(
                id: id,
                completed: completed,
                completionNotes: completionNotes
            )
            if let index = items.firstIndex(where: { $0.id == id }) {
                items[index] = updatedItem
            }
            print("✅ ItemViewModel: Completed item: \(updatedItem.title)")
            print("🔍 ItemViewModel: completed_at: \(updatedItem.completed_at ?? "nil")")
            print("🔍 ItemViewModel: isCompleted: \(updatedItem.isCompleted)")
        } catch {
            self.error = ErrorHandler.shared.handle(error)
            print("❌ ItemViewModel: Failed to complete item: \(error)")
        }
        
        isLoading = false
    }
    
    func reassignItem(id: Int, newOwnerId: Int, reason: String?) async {
        isLoading = true
        error = nil
        
        do {
            let updatedItem = try await itemService.reassignItem(
                id: id,
                newOwnerId: newOwnerId,
                reason: reason
            )
            if let index = items.firstIndex(where: { $0.id == id }) {
                items[index] = updatedItem
            }
            print("✅ ItemViewModel: Reassigned item: \(updatedItem.title)")
        } catch {
            self.error = ErrorHandler.shared.handle(error)
            print("❌ ItemViewModel: Failed to reassign item: \(error)")
        }
        
        isLoading = false
    }
    
    func addExplanation(id: Int, explanation: String) async {
        isLoading = true
        error = nil
        
        do {
            let updatedItem = try await itemService.addExplanation(id: id, explanation: explanation)
            if let index = items.firstIndex(where: { $0.id == id }) {
                items[index] = updatedItem
            }
            print("✅ ItemViewModel: Added explanation to item: \(updatedItem.title)")
        } catch {
            self.error = ErrorHandler.shared.handle(error)
            print("❌ ItemViewModel: Failed to add explanation: \(error)")
        }
        
        isLoading = false
    }
    
    func clearError() {
        error = nil
    }
}
