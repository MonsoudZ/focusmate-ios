import SwiftUI

struct ReassignView: View {
  let item: Item
  let itemViewModel: ItemViewModel
  @Environment(\.dismiss) var dismiss

  @State private var reason = ""
  @State private var selectedOwnerId: Int?
  @State private var availableUsers: [UserDTO] = []
  @State private var isLoadingUsers = false

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Task Details")) {
          VStack(alignment: .leading, spacing: 4) {
            Text(self.item.title)
              .font(.headline)

            if let description = item.description {
              Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            }

            HStack {
              Spacer()

              if let dueDate = item.dueDate {
                Text(dueDate, style: .date)
                  .font(.caption)
                  .foregroundColor(dueDate < Date() ? .red : .secondary)
              }
            }
          }
          .padding(.vertical, 4)
        }

        Section(header: Text("Reassignment Details")) {
          if self.isLoadingUsers {
            HStack {
              ProgressView()
                .scaleEffect(0.8)
              Text("Loading available users...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
          } else {
            Picker("Assign to", selection: self.$selectedOwnerId) {
              Text("Select a user").tag(nil as Int?)
              ForEach(self.availableUsers, id: \.id) { user in
                Text(user.name ?? user.email).tag(Int(user.id) as Int?)
              }
            }
            .pickerStyle(.menu)
          }

          TextField("Reason for reassignment", text: self.$reason, axis: .vertical)
            .lineLimit(3 ... 6)
        }

        Section(
          footer: Text(
            "Reassigning a task will notify the new owner and provide context about why the change was made."
          )
        ) {
          EmptyView()
        }
      }
      .navigationTitle("Reassign Task")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            self.dismiss()
          }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Reassign") {
            Task {
              await self.reassignTask()
            }
          }
          .disabled(self.reason.isEmpty || self.selectedOwnerId == nil || self.itemViewModel.isLoading)
        }
      }
      .task {
        await self.loadAvailableUsers()
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

  private func loadAvailableUsers() async {
    self.isLoadingUsers = true

    // In a real app, you'd fetch available users from the API
    // For now, we'll simulate with some dummy data
    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay

    self.availableUsers = [
      UserDTO(
        id: 1,
        email: "coach@example.com",
        name: "Sarah Johnson",
        role: "coach",
        timezone: "UTC"
      ),
      UserDTO(
        id: 2,
        email: "teammate@example.com",
        name: "Mike Chen",
        role: "client",
        timezone: "UTC"
      ),
      UserDTO(
        id: 3,
        email: "manager@example.com",
        name: "Alex Rodriguez",
        role: "coach",
        timezone: "UTC"
      ),
    ]

    self.isLoadingUsers = false
  }

  private func reassignTask() async {
    guard let newOwnerId = selectedOwnerId else { return }

    await self.itemViewModel.reassignItem(
      id: self.item.id,
      newOwnerId: newOwnerId,
      reason: self.reason
    )

    if self.itemViewModel.error == nil {
      self.dismiss()
    }
  }

  // Removed priorityColor since Item no longer has a Priority enum
}
