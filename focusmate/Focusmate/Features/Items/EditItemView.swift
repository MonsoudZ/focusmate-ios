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
    let apiClient = APIClient(tokenProvider: { AppState().auth.jwt })
    _itemViewModel = StateObject(wrappedValue: ItemViewModel(
      itemService: itemService,
      swiftDataManager: SwiftDataManager.shared,
      // deltaSyncService: DeltaSyncService( // Temporarily disabled
      //   apiClient: apiClient,
      //   swiftDataManager: SwiftDataManager.shared
      // ),
      apiClient: apiClient
    ))

    // Initialize state with current item values
    _name = State(initialValue: item.title)
    _description = State(initialValue: item.description ?? "")
    _dueDate = State(initialValue: item.dueDate ?? Date())
    _hasDueDate = State(initialValue: item.dueDate != nil)
    _isVisible = State(initialValue: item.is_visible)
  }

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Item Details")) {
          TextField("Name", text: self.$name)

          TextField("Description (Optional)", text: self.$description, axis: .vertical)
            .lineLimit(3 ... 6)
        }

        Section(header: Text("Due Date")) {
          Toggle("Set due date", isOn: self.$hasDueDate)

          if self.hasDueDate {
            DatePicker("Due Date", selection: self.$dueDate, displayedComponents: [.date, .hourAndMinute])
          }
        }

        Section(header: Text("Visibility")) {
          Toggle("Visible to others", isOn: self.$isVisible)
            .help("When enabled, this task will be visible to other users who have access to this list")
        }
      }
      .navigationTitle("Edit Item")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            self.dismiss()
          }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Save") {
            Task {
              await self.updateItem()
            }
          }
          .disabled(self.name.isEmpty || self.itemViewModel.isLoading)
        }
      }
      .alert("Error", isPresented: .constant(self.itemViewModel.error != nil)) {
        Button("OK") {
          self.itemViewModel.clearError()
        }
      } message: {
        if let error = itemViewModel.error {
          Text(error.errorDescription ?? "An error occurred")
        }
      }
    }
  }

  private func updateItem() async {
    await self.itemViewModel.updateItem(
      id: self.item.id,
      name: self.name,
      description: self.description.isEmpty ? nil : self.description,
      completed: nil, // Don't change completion status
      dueDate: self.hasDueDate ? self.dueDate : nil,
      isVisible: self.isVisible
    )

    if self.itemViewModel.error == nil {
      self.dismiss()
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
    completed_at: nil as String?,
    priority: 2,
    can_be_snoozed: true,
    notification_interval_minutes: 10,
    requires_explanation_if_missed: false,
    overdue: false,
    minutes_overdue: 0,
    requires_explanation: false,
    is_recurring: false,
    recurrence_pattern: nil as String?,
    recurrence_interval: 1,
    recurrence_days: nil as [Int]?,
    location_based: false,
    location_name: nil as String?,
    location_latitude: nil as Double?,
    location_longitude: nil as Double?,
    location_radius_meters: 100,
    notify_on_arrival: true,
    notify_on_departure: false,
    missed_reason: nil as String?,
    missed_reason_submitted_at: nil as String?,
    missed_reason_reviewed_at: nil as String?,
    creator: UserDTO(
      id: "1",
      email: "test@example.com",
      name: "Test User"
    ),
    created_by_coach: false,
    can_edit: true,
    can_delete: true,
    can_complete: true,
    is_visible: true,
    escalation: nil as Escalation?,
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
      swiftDataManager: SwiftDataManager.shared
    )
  )
}
