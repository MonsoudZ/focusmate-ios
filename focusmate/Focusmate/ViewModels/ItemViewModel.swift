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
        setupTaskUpdateListener()
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
                // Temporary workaround: If Rails API doesn't set completed_at, set it locally
                if completed && updatedItem.completed_at == nil {
                    print("🔧 ItemViewModel: Rails API didn't set completed_at, setting locally")
                    var localItem = updatedItem
                    // Create a new Item with completed_at set to current time
                    let currentTime = Date().ISO8601Format()
                    localItem = Item(
                        id: localItem.id,
                        list_id: localItem.list_id,
                        title: localItem.title,
                        description: localItem.description,
                        due_at: localItem.due_at,
                        completed_at: currentTime, // Set completion time
                        priority: localItem.priority,
                        can_be_snoozed: localItem.can_be_snoozed,
                        notification_interval_minutes: localItem.notification_interval_minutes,
                        requires_explanation_if_missed: localItem.requires_explanation_if_missed,
                        overdue: localItem.overdue,
                        minutes_overdue: localItem.minutes_overdue,
                        requires_explanation: localItem.requires_explanation,
                        is_recurring: localItem.is_recurring,
                        recurrence_pattern: localItem.recurrence_pattern,
                        recurrence_interval: localItem.recurrence_interval,
                        recurrence_days: localItem.recurrence_days,
                        location_based: localItem.location_based,
                        location_name: localItem.location_name,
                        location_latitude: localItem.location_latitude,
                        location_longitude: localItem.location_longitude,
                        location_radius_meters: localItem.location_radius_meters,
                        notify_on_arrival: localItem.notify_on_arrival,
                        notify_on_departure: localItem.notify_on_departure,
                        missed_reason: localItem.missed_reason,
                        missed_reason_submitted_at: localItem.missed_reason_submitted_at,
                        missed_reason_reviewed_at: localItem.missed_reason_reviewed_at,
                        creator: localItem.creator,
                        created_by_coach: localItem.created_by_coach,
                        can_edit: localItem.can_edit,
                        can_delete: localItem.can_delete,
                        can_complete: localItem.can_complete,
                        escalation: localItem.escalation,
                        has_subtasks: localItem.has_subtasks,
                        subtasks_count: localItem.subtasks_count,
                        subtasks_completed_count: localItem.subtasks_completed_count,
                        subtask_completion_percentage: localItem.subtask_completion_percentage,
                        created_at: localItem.created_at,
                        updated_at: localItem.updated_at
                    )
                    items[index] = localItem
                } else {
                    items[index] = updatedItem
                }
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
    
    // MARK: - Real-time Task Updates
    
    private func setupTaskUpdateListener() {
        NotificationCenter.default.addObserver(
            forName: .mergeTaskUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleTaskUpdate(notification)
        }
    }
    
    private func handleTaskUpdate(_ notification: Notification) {
        guard let updatedTask = notification.userInfo?["updatedTask"] as? Item else {
            print("🔌 ItemViewModel: Invalid task update data")
            return
        }
        
        print("🔌 ItemViewModel: Received task update for item \(updatedTask.id)")
        
        // Find and merge the updated task
        if let index = items.firstIndex(where: { $0.id == updatedTask.id }) {
            let oldTask = items[index]
            items[index] = updatedTask
            
            print("✅ ItemViewModel: Merged task update for '\(updatedTask.title)'")
            print("🔍 ItemViewModel: Status changed from \(oldTask.isCompleted) to \(updatedTask.isCompleted)")
            
            // Log specific changes
            if oldTask.title != updatedTask.title {
                print("🔍 ItemViewModel: Title changed from '\(oldTask.title)' to '\(updatedTask.title)'")
            }
            if oldTask.completed_at != updatedTask.completed_at {
                print("🔍 ItemViewModel: Completion status changed")
            }
            if oldTask.description != updatedTask.description {
                print("🔍 ItemViewModel: Description updated")
            }
        } else {
            // Task doesn't exist in current list, might be from another list
            print("🔌 ItemViewModel: Task \(updatedTask.id) not found in current list")
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
