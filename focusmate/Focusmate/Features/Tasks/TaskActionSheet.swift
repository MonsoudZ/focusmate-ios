import SwiftUI

struct TaskActionSheet: View {
    let item: Item
    let itemViewModel: ItemViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var showingReassign = false
    @State private var showingExplanation = false
    @State private var showingEscalation = false
    @State private var completionNotes = ""
    @State private var showingCompletionForm = false
    @State private var showingEditForm = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Task Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            if let description = item.description {
                                Text(description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            if let dueDate = item.dueDate {
                                Text(dueDate, style: .date)
                                    .font(.caption)
                                    .foregroundColor(dueDate < Date() ? .red : .secondary)
                            }
                        }
                    }
                    
                    HStack {
                        Label("Created \(item.created_at)", systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if item.isCompleted {
                            VStack(alignment: .trailing, spacing: 2) {
                                Label("Completed", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .fontWeight(.medium)
                                
                                if let completedAt = item.completed_at {
                                    Text("Completed at \(completedAt)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Action Buttons
                VStack(spacing: 16) {
                    // Primary Actions
                    VStack(spacing: 12) {
                        if !item.isCompleted {
                            Button(action: { showingCompletionForm = true }) {
                                HStack {
                                    Image(systemName: "checkmark.circle")
                                    Text("Mark as Complete")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        } else {
                            Button(action: { toggleCompletion() }) {
                                HStack {
                                    Image(systemName: "arrow.uturn.backward.circle")
                                    Text("Mark as Incomplete")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        
                        Button(action: { showingReassign = true }) {
                            HStack {
                                Image(systemName: "person.2")
                                Text("Reassign Task")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    
                    // Secondary Actions
                    VStack(spacing: 8) {
                        Button(action: { showingEditForm = true }) {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Edit Task")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .disabled(!item.can_edit)
                        
                        Button(action: { showingExplanation = true }) {
                            HStack {
                                Image(systemName: "text.bubble")
                                Text("Add Explanation")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        Button(action: { showingEscalation = true }) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                Text("Escalate Task")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Task Actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingEditForm) {
                EditItemView(item: item, itemService: ItemService(
                    apiClient: APIClient(tokenProvider: { AppState().auth.jwt }),
                    swiftDataManager: SwiftDataManager.shared,
                    deltaSyncService: DeltaSyncService(
                        apiClient: APIClient(tokenProvider: { AppState().auth.jwt }),
                        swiftDataManager: SwiftDataManager.shared
                    )
                ))
            }
            .sheet(isPresented: $showingReassign) {
                ReassignView(item: item, itemViewModel: itemViewModel)
            }
            .sheet(isPresented: $showingExplanation) {
                ExplanationFormView(
                    itemId: item.id,
                    itemName: item.title,
                    escalationService: EscalationService(apiClient: APIClient { nil })
                )
            }
            .sheet(isPresented: $showingEscalation) {
                EscalationFormView(
                    itemId: item.id,
                    itemName: item.title,
                    escalationService: EscalationService(apiClient: APIClient { nil })
                )
            }
            .sheet(isPresented: $showingCompletionForm) {
                CompletionFormView(item: item, itemViewModel: itemViewModel)
            }
        }
    }
    
    private func toggleCompletion() {
        Task {
            await itemViewModel.completeItem(
                id: item.id,
                completed: !item.isCompleted,
                completionNotes: nil
            )
        }
    }
    
    // Removed priorityColor since Item no longer has a Priority enum
}

struct CompletionFormView: View {
    let item: Item
    let itemViewModel: ItemViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var completionNotes = ""
    
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
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Completion Notes")) {
                    TextField("Add notes about completion (optional)", text: $completionNotes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(footer: Text("Completion notes help track what was accomplished and any important details.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Complete Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Complete") {
                        Task {
                            await completeTask()
                        }
                    }
                    .disabled(itemViewModel.isLoading)
                }
            }
        }
    }
    
    private func completeTask() async {
        await itemViewModel.completeItem(
            id: item.id,
            completed: true,
            completionNotes: completionNotes.isEmpty ? nil : completionNotes
        )
        
        if itemViewModel.error == nil {
            dismiss()
        }
    }
    
}
