import SwiftUI
import SwiftData

struct ListDetailView: View {
    let list: ListDTO
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var swiftDataManager: SwiftDataManager
    @EnvironmentObject var deltaSyncService: DeltaSyncService
    @StateObject private var itemViewModel: ItemViewModel
    
    @State private var showingCreateItem = false
    @State private var showingEditList = false
    @State private var showingDeleteConfirmation = false
    @State private var showingShareList = false
    @State private var shares: [ListShare] = []
    @Environment(\.dismiss) private var dismiss
    
    init(list: ListDTO, itemService: ItemService) {
        self.list = list
        self._itemViewModel = StateObject(wrappedValue: ItemViewModel(
            itemService: itemService,
            swiftDataManager: SwiftDataManager.shared,
            deltaSyncService: DeltaSyncService(
                apiClient: APIClient(tokenProvider: { AppState().auth.jwt }),
                swiftDataManager: SwiftDataManager.shared
            )
        ))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // List Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(list.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if let description = list.description {
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Button("Share") {
                            showingShareList = true
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Edit") {
                            showingEditList = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                HStack {
                    Label("\(list.tasksCount) tasks", systemImage: "list.bullet")
                    
                    if !shares.isEmpty {
                        Label("\(shares.count) shared", systemImage: "person.2")
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    if list.overdueTasksCount > 0 {
                        Label("\(list.overdueTasksCount) overdue", systemImage: "exclamationmark.triangle")
                            .foregroundColor(.red)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            
            // Items List
            if itemViewModel.isLoading {
                ProgressView("Loading items...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if itemViewModel.items.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No items yet")
                        .font(.title3)
                        .fontWeight(.medium)
                    
                    Text("Tap the + button to add your first item")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(itemViewModel.items) { item in
                        NavigationLink(destination: TaskActionSheet(item: item, itemViewModel: itemViewModel)) {
                            ItemRowView(item: item) {
                                Task {
                                    await itemViewModel.completeItem(
                                        id: item.id,
                                        completed: !item.isCompleted,
                                        completionNotes: nil
                                    )
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let item = itemViewModel.items[index]
                            Task {
                                await itemViewModel.deleteItem(id: item.id)
                            }
                        }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Delete List", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingCreateItem = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateItem) {
            CreateItemView(
                listId: list.id, 
                itemService: ItemService(
                    apiClient: appState.auth.api,
                    swiftDataManager: SwiftDataManager.shared,
                    deltaSyncService: DeltaSyncService(
                        apiClient: appState.auth.api,
                        swiftDataManager: SwiftDataManager.shared
                    )
                )
            )
        }
        .sheet(isPresented: $showingEditList) {
            EditListView(list: list, listService: ListService(apiClient: appState.auth.api))
        }
        .sheet(isPresented: $showingShareList) {
            ShareListView(list: list, listService: ListService(apiClient: appState.auth.api))
        }
        .task {
            await itemViewModel.loadItems(listId: list.id)
            await loadShares()
        }
        .alert("Delete List", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteList()
                }
            }
        } message: {
            Text("Are you sure you want to delete '\(list.name)'? This action cannot be undone.")
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
    
    private func deleteList() async {
        do {
            let listService = ListService(apiClient: appState.auth.api)
            try await listService.deleteList(id: list.id)
            print("✅ ListDetailView: Deleted list \(list.name) (ID: \(list.id))")
            dismiss() // Navigate back to lists view
        } catch {
            print("❌ ListDetailView: Failed to delete list: \(error)")
            // You could add error handling here if needed
        }
    }
    
    private func loadShares() async {
        do {
            let listService = ListService(apiClient: appState.auth.api)
            shares = try await listService.fetchShares(listId: list.id)
            print("✅ ListDetailView: Loaded \(shares.count) shares for list \(list.id)")
        } catch {
            print("❌ ListDetailView: Failed to load shares: \(error)")
        }
    }
}

struct ItemRowView: View {
    let item: Item
    let onToggleComplete: () -> Void
    
    var body: some View {
        HStack {
            Button {
                onToggleComplete()
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isCompleted ? .green : .secondary)
                    .font(.title2)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .fontWeight(item.isCompleted ? .regular : .medium)
                    .strikethrough(item.isCompleted)
                
                if let description = item.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    if let dueDate = item.dueDate {
                        Text(dueDate, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Show completion details for completed tasks
                    if item.isCompleted, let completedAt = item.completed_at {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Completed")
                                .font(.caption2)
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                            
                            Text(formatCompletionTime(completedAt))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .opacity(item.isCompleted ? 0.6 : 1.0) // Fade out completed tasks
        .animation(.easeInOut(duration: 0.3), value: item.isCompleted)
    }
    
    private func formatCompletionTime(_ completedAt: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: completedAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return "Recently"
    }
    
    // Removed priorityColor since Item no longer has a Priority enum
}
