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
  @State private var isRecurring: Bool
  @State private var recurrencePattern: String
  @State private var recurrenceInterval: Int
  @State private var selectedWeekdays: Set<Int>
  @State private var locationBased: Bool
  @State private var locationName: String
  @State private var locationLatitude: Double?
  @State private var locationLongitude: Double?
  @State private var locationRadius: Int
  @State private var notifyOnArrival: Bool
  @State private var notifyOnDeparture: Bool
  @State private var showLocationPicker = false

  init(item: Item, itemService: ItemService) {
    self.item = item
    self.itemService = itemService
    let apiClient = APIClient(tokenProvider: { AppState().auth.jwt })
    _itemViewModel = StateObject(wrappedValue: ItemViewModel(
      itemService: itemService,
      swiftDataManager: SwiftDataManager.shared,
      apiClient: apiClient
    ))

    // Initialize state with current item values
    _name = State(initialValue: item.title)
    _description = State(initialValue: item.description ?? "")
    _dueDate = State(initialValue: item.dueDate ?? Date())
    _hasDueDate = State(initialValue: item.dueDate != nil)
    _isVisible = State(initialValue: item.is_visible)
    _isRecurring = State(initialValue: item.is_recurring)
    _recurrencePattern = State(initialValue: item.recurrence_pattern ?? "daily")
    _recurrenceInterval = State(initialValue: item.recurrence_interval)
    _selectedWeekdays = State(initialValue: Set(item.recurrence_days ?? []))
    _locationBased = State(initialValue: item.location_based)
    _locationName = State(initialValue: item.location_name ?? "")
    _locationLatitude = State(initialValue: item.location_latitude)
    _locationLongitude = State(initialValue: item.location_longitude)
    _locationRadius = State(initialValue: item.location_radius_meters)
    _notifyOnArrival = State(initialValue: item.notify_on_arrival)
    _notifyOnDeparture = State(initialValue: item.notify_on_departure)
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
            DatePicker("Due Date", selection: self.$dueDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
          }
        }

        Section(header: Text("Visibility")) {
          Toggle("Visible to others", isOn: self.$isVisible)
            .help("When enabled, this task will be visible to other users who have access to this list")
        }

        Section(header: Text("Recurring Task")) {
          Toggle("Repeat this task", isOn: self.$isRecurring)

          if self.isRecurring {
            Picker("Frequency", selection: self.$recurrencePattern) {
              Text("Daily").tag("daily")
              Text("Weekly").tag("weekly")
              Text("Monthly").tag("monthly")
            }

            Stepper("Every \(self.recurrenceInterval) \(self.recurrencePattern == "daily" ? "day(s)" : self.recurrencePattern == "weekly" ? "week(s)" : "month(s)")", value: self.$recurrenceInterval, in: 1...30)

            if self.recurrencePattern == "weekly" {
              VStack(alignment: .leading, spacing: 8) {
                Text("Repeat on:")
                  .font(.caption)
                  .foregroundColor(.secondary)

                HStack(spacing: 8) {
                  ForEach([(0, "Sun"), (1, "Mon"), (2, "Tue"), (3, "Wed"), (4, "Thu"), (5, "Fri"), (6, "Sat")], id: \.0) { day in
                    Button(action: {
                      if self.selectedWeekdays.contains(day.0) {
                        self.selectedWeekdays.remove(day.0)
                      } else {
                        self.selectedWeekdays.insert(day.0)
                      }
                    }) {
                      Text(day.1)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(self.selectedWeekdays.contains(day.0) ? Color.blue : Color.gray.opacity(0.2))
                        .foregroundColor(self.selectedWeekdays.contains(day.0) ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                  }
                }
              }
            }
          }
        }

        Section(header: Text("Location-Based")) {
          Toggle("Trigger at location", isOn: self.$locationBased)
            .help("Get notified when you arrive at or leave a specific location")

          if self.locationBased {
            if let lat = locationLatitude, let lon = locationLongitude {
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  VStack(alignment: .leading, spacing: 4) {
                    if !locationName.isEmpty {
                      Text(locationName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    }
                    Text("Lat: \(lat, specifier: "%.6f"), Lon: \(lon, specifier: "%.6f")")
                      .font(.caption)
                      .foregroundColor(.secondary)
                  }

                  Spacer()

                  Button("Change") {
                    showLocationPicker = true
                  }
                  .font(.caption)
                }

                Text("Radius: \(locationRadius)m")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            } else {
              Button(action: {
                showLocationPicker = true
              }) {
                HStack {
                  Image(systemName: "mappin.and.ellipse")
                  Text("Pick Location")
                }
              }
            }

            Toggle("Notify on arrival", isOn: self.$notifyOnArrival)
            Toggle("Notify on departure", isOn: self.$notifyOnDeparture)
          }
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
      .sheet(isPresented: self.$showLocationPicker) {
        LocationPickerView(
          locationService: LocationService(),
          locationName: self.$locationName,
          latitude: self.$locationLatitude,
          longitude: self.$locationLongitude,
          radius: self.$locationRadius
        )
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
      isVisible: self.isVisible,
      isRecurring: self.isRecurring,
      recurrencePattern: self.isRecurring ? self.recurrencePattern : nil,
      recurrenceInterval: self.isRecurring ? self.recurrenceInterval : nil,
      recurrenceDays: (self.isRecurring && self.recurrencePattern == "weekly") ? Array(self.selectedWeekdays).sorted() : nil,
      locationBased: self.locationBased,
      locationName: self.locationBased ? self.locationName : nil,
      locationLatitude: self.locationBased ? self.locationLatitude : nil,
      locationLongitude: self.locationBased ? self.locationLongitude : nil,
      locationRadiusMeters: self.locationBased ? self.locationRadius : nil,
      notifyOnArrival: self.locationBased ? self.notifyOnArrival : false,
      notifyOnDeparture: self.locationBased ? self.notifyOnDeparture : false
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
      id: 1,
      email: "test@example.com",
      name: "Test User",
      role: "client",
      timezone: "UTC"
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
