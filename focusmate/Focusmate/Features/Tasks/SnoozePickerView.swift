import SwiftUI

struct SnoozePickerView: View {
  let item: Item
  let itemViewModel: ItemViewModel
  @Environment(\.dismiss) var dismiss

  @State private var selectedOption: SnoozeOption = .fifteenMinutes
  @State private var customDate = Date().addingTimeInterval(3600) // 1 hour from now
  @State private var isCustom = false

  enum SnoozeOption: String, CaseIterable {
    case fifteenMinutes = "15 minutes"
    case thirtyMinutes = "30 minutes"
    case oneHour = "1 hour"
    case threeHours = "3 hours"
    case tomorrow = "Tomorrow"
    case nextWeek = "Next week"
    case custom = "Custom"

    var timeInterval: TimeInterval? {
      switch self {
      case .fifteenMinutes:
        return 15 * 60
      case .thirtyMinutes:
        return 30 * 60
      case .oneHour:
        return 60 * 60
      case .threeHours:
        return 3 * 60 * 60
      case .tomorrow:
        return 24 * 60 * 60
      case .nextWeek:
        return 7 * 24 * 60 * 60
      case .custom:
        return nil
      }
    }

    var date: Date? {
      guard let interval = timeInterval else { return nil }
      return Date().addingTimeInterval(interval)
    }
  }

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Task")) {
          VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
              .font(.headline)

            if let description = item.description {
              Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
          }
          .padding(.vertical, 4)
        }

        Section(header: Text("Snooze Until")) {
          ForEach(SnoozeOption.allCases, id: \.self) { option in
            Button(action: {
              selectedOption = option
              isCustom = (option == .custom)
            }) {
              HStack {
                Text(option.rawValue)
                  .foregroundColor(.primary)
                Spacer()
                if selectedOption == option {
                  Image(systemName: "checkmark")
                    .foregroundColor(.blue)
                }
              }
            }
          }
        }

        if isCustom {
          Section(header: Text("Custom Date & Time")) {
            DatePicker(
              "Snooze until",
              selection: $customDate,
              in: Date()...,
              displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.graphical)
          }
        }

        Section {
          Button(action: {
            Task {
              await snoozeTask()
            }
          }) {
            HStack {
              Spacer()
              if itemViewModel.isLoading {
                ProgressView()
                  .progressViewStyle(.circular)
              } else {
                Text("Snooze Task")
                  .fontWeight(.semibold)
              }
              Spacer()
            }
          }
          .disabled(itemViewModel.isLoading)
        }
      }
      .navigationTitle("Snooze Task")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
        }
      }
    }
  }

  private func snoozeTask() async {
    let snoozeDate = isCustom ? customDate : (selectedOption.date ?? Date())

    await itemViewModel.snoozeItem(id: item.id, snoozeUntil: snoozeDate)

    if itemViewModel.error == nil {
      dismiss()
    }
  }
}

#Preview {
  SnoozePickerView(
    item: Item(
      id: 1,
      list_id: 1,
      title: "Sample Task",
      description: "This is a sample task",
      due_at: nil,
      completed_at: nil,
      priority: 1,
      can_be_snoozed: true,
      notification_interval_minutes: 15,
      requires_explanation_if_missed: false,
      overdue: false,
      minutes_overdue: 0,
      requires_explanation: false,
      is_recurring: false,
      recurrence_pattern: nil,
      recurrence_interval: 0,
      recurrence_days: nil,
      location_based: false,
      location_name: nil,
      location_latitude: nil,
      location_longitude: nil,
      location_radius_meters: 0,
      notify_on_arrival: false,
      notify_on_departure: false,
      missed_reason: nil,
      missed_reason_submitted_at: nil,
      missed_reason_reviewed_at: nil,
      creator: UserDTO(id: 1, email: "test@example.com", name: "Test User", role: "client", timezone: nil),
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
    ),
    itemViewModel: ItemViewModel(
      itemService: ItemService(
        apiClient: APIClient(tokenProvider: { nil }),
        swiftDataManager: SwiftDataManager.shared
      ),
      swiftDataManager: SwiftDataManager.shared,
      apiClient: APIClient(tokenProvider: { nil })
    )
  )
}
