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
                        Text(item.title)
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
                    if isLoadingUsers {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading available users...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Picker("Assign to", selection: $selectedOwnerId) {
                            Text("Select a user").tag(nil as Int?)
                            ForEach(availableUsers, id: \.id) { user in
                                Text(user.name ?? user.email).tag(user.id as Int?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    TextField("Reason for reassignment", text: $reason, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(footer: Text("Reassigning a task will notify the new owner and provide context about why the change was made.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Reassign Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reassign") {
                        Task {
                            await reassignTask()
                        }
                    }
                    .disabled(reason.isEmpty || selectedOwnerId == nil || itemViewModel.isLoading)
                }
            }
            .task {
                await loadAvailableUsers()
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
    
    private func loadAvailableUsers() async {
        isLoadingUsers = true
        
        // In a real app, you'd fetch available users from the API
        // For now, we'll simulate with some dummy data
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        availableUsers = [
            UserDTO(id: 1, email: "coach@example.com", name: "Sarah Johnson", role: "coach", timezone: "UTC", created_at: nil),
            UserDTO(id: 2, email: "teammate@example.com", name: "Mike Chen", role: "client", timezone: "UTC", created_at: nil),
            UserDTO(id: 3, email: "manager@example.com", name: "Alex Rodriguez", role: "client", timezone: "UTC", created_at: nil)
        ]
        
        isLoadingUsers = false
    }
    
    private func reassignTask() async {
        guard let newOwnerId = selectedOwnerId else { return }
        
        await itemViewModel.reassignItem(
            id: item.id,
            newOwnerId: newOwnerId,
            reason: reason
        )
        
        if itemViewModel.error == nil {
            dismiss()
        }
    }
    
    // Removed priorityColor since Item no longer has a Priority enum
}
