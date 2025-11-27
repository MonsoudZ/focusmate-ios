import SwiftUI

struct CreateItemView: View {
  let listId: Int
  let itemService: ItemService
  @Environment(\.dismiss) var dismiss
  @StateObject private var itemViewModel: ItemViewModel

  @State private var name = ""
  @State private var description = ""
  @State private var dueDate = Date()
  @State private var hasDueDate = false
  @State private var isVisible = true
  @State private var isRecurring = false
  @State private var recurrencePattern = "daily"
  @State private var recurrenceInterval = 1
  @State private var selectedWeekdays: Set<Int> = []
  @State private var locationBased = false
  @State private var locationName = ""
  @State private var locationLatitude: Double?
  @State private var locationLongitude: Double?
  @State private var locationRadius = 100
  @State private var notifyOnArrival = false
  @State private var notifyOnDeparture = false
  @State private var showLocationPicker = false

  init(listId: Int, itemService: ItemService) {
    self.listId = listId
    self.itemService = itemService
    let apiClient = APIClient(tokenProvider: { AppState().auth.jwt })
    _itemViewModel = StateObject(wrappedValue: ItemViewModel(
      itemService: itemService,
      swiftDataManager: SwiftDataManager.shared,
      apiClient: apiClient
    ))
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
      .navigationTitle("New Item")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            self.dismiss()
          }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Create") {
            Task {
              await self.createItem()
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

  private func createItem() async {
    // Add client-side validation
    guard !self.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      #if DEBUG
      print("❌ CreateItemView: Title is required")
      #endif
      return
    }

    let trimmedName = self.name.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedDescription = self.description.trimmingCharacters(in: .whitespacesAndNewlines)

    #if DEBUG
    print("🔍 CreateItemView: Creating item with title: '\(trimmedName)'")
    #endif

    await self.itemViewModel.createItem(
      listId: self.listId,
      name: trimmedName,
      description: trimmedDescription.isEmpty ? nil : trimmedDescription,
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
      // Trigger refresh of items list
      RefreshCoordinator.shared.triggerRefresh(.items(listId: self.listId))
      self.dismiss()
    }
  }
}
