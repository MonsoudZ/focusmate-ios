import SwiftUI

struct SearchView: View {
    let taskService: TaskService
    let listService: ListService
    var onSelectList: ((ListDTO) -> Void)?
    @Environment(\.dismiss) private var dismiss
    
    @State private var query = ""
    @State private var results: [TaskDTO] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var taskToEdit: TaskDTO?
    @State private var error: FocusmateError?
    @State private var lists: [Int: ListDTO] = [:]
    
    // Group tasks by list_id
    private var groupedResults: [(listId: Int, tasks: [TaskDTO])] {
        let grouped = Dictionary(grouping: results) { $0.list_id }
        return grouped.map { (listId: $0.key, tasks: $0.value) }
            .sorted { $0.listId < $1.listId }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchResults
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $query, prompt: "Search tasks...")
            .onSubmit(of: .search) {
                Task { await search() }
            }
            .onChange(of: query) { oldValue, newValue in
                if newValue.isEmpty {
                    results = []
                    hasSearched = false
                }
            }
            .sheet(item: $taskToEdit) { task in
                EditTaskView(
                    listId: task.list_id,
                    task: task,
                    taskService: taskService,
                    onSave: {
                        Task { await search() }
                    }
                )
            }
            .errorBanner($error)
        }
    }
    
    @ViewBuilder
    private var searchResults: some View {
        if isSearching {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if results.isEmpty && hasSearched {
            ContentUnavailableView(
                "No Results",
                systemImage: "magnifyingglass",
                description: Text("No tasks found for \"\(query)\"")
            )
        } else if results.isEmpty {
            ContentUnavailableView(
                "Search Tasks",
                systemImage: "magnifyingglass",
                description: Text("Search by title or notes")
            )
        } else {
            List {
                ForEach(groupedResults, id: \.listId) { group in
                    Section {
                        ForEach(group.tasks, id: \.id) { task in
                            SearchResultRow(task: task)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    HapticManager.selection()
                                    taskToEdit = task
                                }
                        }
                    } header: {
                        if let list = lists[group.listId] {
                            Button {
                                HapticManager.selection()
                                dismiss()
                                onSelectList?(list)
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(list.listColor)
                                        .frame(width: 10, height: 10)
                                    Text(list.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                }
                                .foregroundColor(DesignSystem.Colors.primary)
                            }
                        } else {
                            Text("List \(group.listId)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }
    
    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        isSearching = true
        hasSearched = true
        
        do {
            results = try await taskService.searchTasks(query: trimmed)
            await loadListsForResults()
        } catch let err as FocusmateError {
            error = err
            HapticManager.error()
        } catch {
            self.error = .custom("SEARCH_ERROR", error.localizedDescription)
            HapticManager.error()
        }
        
        isSearching = false
    }
    
    private func loadListsForResults() async {
        let listIds = Set(results.map { $0.list_id })
        
        do {
            let allLists = try await listService.fetchLists()
            for list in allLists {
                if listIds.contains(list.id) {
                    lists[list.id] = list
                }
            }
        } catch {
            Logger.error("Failed to load lists for search results: \(error)", category: .api)
        }
    }
}

struct SearchResultRow: View {
    let task: TaskDTO
    
    private var isOverdue: Bool {
        guard let dueDate = task.dueDate, !task.isCompleted else { return false }
        return dueDate < Date()
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: task.isCompleted ? DesignSystem.Icons.taskCompleted : DesignSystem.Icons.task)
                .foregroundColor(task.isCompleted ? DesignSystem.Colors.success : task.taskColor)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                HStack(spacing: 4) {
                    if let icon = task.taskPriority.icon {
                        Image(systemName: icon)
                            .foregroundColor(task.taskPriority.color)
                            .font(.caption)
                    }
                    
                    Text(task.title)
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .strikethrough(task.isCompleted)
                        .foregroundColor(isOverdue ? DesignSystem.Colors.overdue : DesignSystem.Colors.textPrimary)
                    
                    if task.isStarred {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }
                
                if let note = task.note, !note.isEmpty {
                    Text(note)
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .opacity(task.isCompleted ? 0.6 : 1.0)
    }
}
