import SwiftUI

struct SearchView: View {
    let tagService: TagService
    var onSelectList: ((ListDTO) -> Void)?
    let initialQuery: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.router) private var router

    @State private var viewModel: SearchViewModel

    init(taskService: TaskService, listService: ListService, tagService: TagService, onSelectList: ((ListDTO) -> Void)? = nil, initialQuery: String = "") {
        self.tagService = tagService
        self.onSelectList = onSelectList
        self.initialQuery = initialQuery
        _viewModel = State(initialValue: SearchViewModel(taskService: taskService, listService: listService, initialQuery: initialQuery))
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
            .searchable(text: $viewModel.query, prompt: "Search tasks...")
            .onSubmit(of: .search) {
                Task { await viewModel.search() }
            }
            .task {
                await viewModel.searchIfNeeded()
            }
            .onChange(of: viewModel.query) { oldValue, newValue in
                if newValue.isEmpty {
                    viewModel.clearSearch()
                }
            }
            .floatingErrorBanner($viewModel.error)
        }
    }

    // MARK: - Sheet Presentation

    private func presentEditTask(_ task: TaskDTO) {
        router.sheetCallbacks.onTaskSaved = {
            Task { await viewModel.search() }
        }
        router.present(.editTask(task, listId: task.list_id))
    }

    @ViewBuilder
    private var searchResults: some View {
        if viewModel.isSearching {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.results.isEmpty && viewModel.hasSearched {
            ContentUnavailableView(
                "No Results",
                systemImage: DS.Icon.search,
                description: Text("No tasks found for \"\(viewModel.query)\"")
            )
        } else if viewModel.results.isEmpty {
            ContentUnavailableView(
                "Search Tasks",
                systemImage: DS.Icon.search,
                description: Text("Search by title or notes")
            )
        } else {
            List {
                ForEach(viewModel.groupedResults, id: \.listId) { group in
                    Section {
                        ForEach(group.tasks, id: \.id) { task in
                            SearchResultRow(task: task)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    HapticManager.selection()
                                    presentEditTask(task)
                                }
                        }
                    } header: {
                        if let list = viewModel.lists[group.listId] {
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
                                        .font(.subheadline.weight(.semibold))
                                    Image(systemName: DS.Icon.chevronRight)
                                        .font(.caption2)
                                }
                                .foregroundStyle(DS.Colors.accent)
                            }
                        } else {
                            Text("List \(group.listId)")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
            .listStyle(.plain)
            .surfaceFormBackground()
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
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: task.isCompleted ? DS.Icon.circleChecked : DS.Icon.circle)
                .foregroundStyle(task.isCompleted ? DS.Colors.success : task.taskColor)
                .font(.title3)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                HStack(spacing: DS.Spacing.xs) {
                    if let icon = task.taskPriority.icon {
                        Image(systemName: icon)
                            .foregroundStyle(task.taskPriority.color)
                            .font(.caption)
                    }

                    Text(task.title)
                        .font(.body.weight(.medium))
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(isOverdue ? DS.Colors.overdue : .primary)

                    if task.isStarred {
                        Image(systemName: DS.Icon.starFilled)
                            .foregroundStyle(.yellow)
                            .font(.caption)
                    }
                }

                if let note = task.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: DS.Icon.chevronRight)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, DS.Spacing.xs)
        .opacity(task.isCompleted ? 0.6 : 1.0)
    }
}
