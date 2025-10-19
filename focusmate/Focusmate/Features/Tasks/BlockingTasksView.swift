import SwiftUI

struct BlockingTasksView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingEscalationForm = false
    @State private var selectedTask: BlockingTask?
    
    private var escalationViewModel: EscalationViewModel {
        EscalationViewModel(escalationService: appState.escalationService)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if escalationViewModel.isLoading {
                    ProgressView("Loading blocking tasks...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if escalationViewModel.blockingTasks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        
                        Text("No Blocking Tasks")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("Great job! No tasks are currently blocking your progress.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(escalationViewModel.blockingTasks, id: \.id) { task in
                                BlockingTaskRowView(task: task) {
                                    selectedTask = task
                                    showingEscalationForm = true
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Blocking Tasks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        Task {
                            await escalationViewModel.loadBlockingTasks()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEscalationForm) {
                if let task = selectedTask {
                    EscalationFormView(itemId: task.id, itemName: task.name, escalationService: appState.escalationService)
                }
            }
            .task {
                await escalationViewModel.loadBlockingTasks()
            }
            .alert("Error", isPresented: .constant(escalationViewModel.error != nil)) {
                Button("OK") {
                    escalationViewModel.clearError()
                }
            } message: {
                if let error = escalationViewModel.error {
                    Text(error.errorDescription ?? "An error occurred")
                }
            }
        }
    }
}

struct BlockingTaskRowView: View {
    let task: BlockingTask
    let onEscalate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.name)
                        .font(.headline)
                        .lineLimit(2)
                    
                    if let description = task.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if task.escalationCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("\(task.escalationCount)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            
            HStack {
                Label(task.listName, systemImage: "list.bullet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let dueDate = task.dueDate {
                    Text(dueDate, style: .date)
                        .font(.caption)
                        .foregroundColor(dueDate < Date() ? .red : .secondary)
                }
            }
            
            if let blockingReason = task.blockingReason {
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(.red)
                    Text(blockingReason)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.top, 4)
            }
            
            Button("Escalate Task") {
                onEscalate()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
    
    // Removed priorityColor since BlockingTask no longer has a Priority enum
}
