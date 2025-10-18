import SwiftUI

struct EditItemView: View {
    let item: Item
    let itemService: ItemService
    @Environment(\.dismiss) var dismiss
    @StateObject private var itemViewModel: ItemViewModel
    
    @State private var name: String
    @State private var description: String
    @State private var dueDate: Date
    @State private var hasDueDate: Bool
    @State private var isVisible: Bool
    
    init(item: Item, itemService: ItemService) {
        self.item = item
        self.itemService = itemService
        self._itemViewModel = StateObject(wrappedValue: ItemViewModel(
            itemService: itemService,
            swiftDataManager: SwiftDataManager.shared,
            deltaSyncService: DeltaSyncService(
                apiClient: APIClient(tokenProvider: { AppState().auth.jwt }),
                swiftDataManager: SwiftDataManager.shared
            )
        ))
        
        // Initialize state with current item values
        self._name = State(initialValue: item.title)
        self._description = State(initialValue: item.description ?? "")
        self._dueDate = State(initialValue: item.dueDate ?? Date())
        self._hasDueDate = State(initialValue: item.dueDate != nil)
        self._isVisible = State(initialValue: item.is_visible)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Item Details")) {
                    TextField("Name", text: $name)
                    
                    TextField("Description (Optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text("Due Date")) {
                    Toggle("Set due date", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                
                Section(header: Text("Visibility")) {
                    Toggle("Visible to others", isOn: $isVisible)
                        .help("When enabled, this task will be visible to other users who have access to this list")
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await updateItem()
                        }
                    }
                    .disabled(name.isEmpty || itemViewModel.isLoading)
                }
            }
            .alert("Error", isPresented: .constant(itemViewModel.error != nil)) {
                Button("OK") {
                    itemViewModel.clearError()
                }
            } message: {
                if let error = itemViewModel.error {
                    Text(error.errorDescription ?? "An error occurred")
                }
            }
        }
    }
    
    private func updateItem() async {
        await itemViewModel.updateItem(
            id: item.id,
            name: name,
            description: description.isEmpty ? nil : description,
            completed: nil, // Don't change completion status
            dueDate: hasDueDate ? dueDate : nil,
            isVisible: isVisible
        )
        
        if itemViewModel.error == nil {
            dismiss()
        }
    }
}

#Preview {
    let mockItem = Item(
        id: 1,
        list_id: 1,
        title: "Sample Task",
        description: "Sample description",
        due_at: Date().ISO8601Format(),
        completed_at: nil,
        priority: 2,
        can_be_snoozed: true,
        notification_interval_minutes: 10,
        requires_explanation_if_missed: false,
        overdue: false,
        minutes_overdue: 0,
        requires_explanation: false,
        is_recurring: false,
        recurrence_pattern: nil,
        recurrence_interval: 1,
        recurrence_days: nil,
        location_based: false,
        location_name: nil,
        location_latitude: nil,
        location_longitude: nil,
        location_radius_meters: 100,
        notify_on_arrival: true,
        notify_on_departure: false,
        missed_reason: nil,
        missed_reason_submitted_at: nil,
        missed_reason_reviewed_at: nil,
        creator: UserDTO(id: 1, email: "test@example.com", name: "Test User", role: "client", timezone: "UTC", created_at: nil),
        created_by_coach: false,
        can_edit: true,
        can_delete: true,
        can_complete: true,
        is_visible: true,
        escalation: nil,
        has_subtasks: false,
        subtasks_count: 0,
        subtasks_completed_count: 0,
        subtask_completion_percentage: 0,
        created_at: Date().ISO8601Format(),
        updated_at: Date().ISO8601Format()
    )
    
    EditItemView(
        item: mockItem,
        itemService: ItemService(
            apiClient: APIClient(tokenProvider: { nil }),
            swiftDataManager: SwiftDataManager.shared,
            deltaSyncService: DeltaSyncService(
                apiClient: APIClient(tokenProvider: { nil }),
                swiftDataManager: SwiftDataManager.shared
            )
        )
    )
}
