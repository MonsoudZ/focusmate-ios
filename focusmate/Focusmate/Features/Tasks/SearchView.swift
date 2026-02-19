import SwiftUI

struct SearchView: View {
  let tagService: TagService
  var onSelectList: ((ListDTO) -> Void)?
  let initialQuery: String
  @Environment(\.dismiss) private var dismiss
  @Environment(\.router) private var router

  @State private var viewModel: SearchViewModel

  init(
    taskService: TaskService,
    listService: ListService,
    tagService: TagService,
    onSelectList: ((ListDTO) -> Void)? = nil,
    initialQuery: String = ""
  ) {
    self.tagService = tagService
    self.onSelectList = onSelectList
    self.initialQuery = initialQuery
    _viewModel = State(initialValue: SearchViewModel(
      taskService: taskService,
      listService: listService,
      initialQuery: initialQuery
    ))
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        self.searchResults
      }
      .navigationTitle("Search")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            self.dismiss()
          }
        }
      }
      .searchable(text: self.$viewModel.query, prompt: "Search tasks...")
      .onSubmit(of: .search) {
        Task { await self.viewModel.search() }
      }
      .task {
        await self.viewModel.searchIfNeeded()
      }
      .onChange(of: self.viewModel.query) { _, newValue in
        if newValue.isEmpty {
          self.viewModel.clearSearch()
        }
      }
      .floatingErrorBanner(self.$viewModel.error)
    }
  }

  // MARK: - Sheet Presentation

  private func presentTask(_ task: TaskDTO) {
    if task.isCompleted {
      // Completed tasks open in read-only detail view
      self.router.sheetCallbacks.onTaskUpdated = {
        Task { await self.viewModel.search() }
      }
      self.router.present(.taskDetail(task, listName: task.list_name ?? "Unknown"))
    } else {
      // Active tasks open in edit view
      self.router.sheetCallbacks.onTaskSaved = {
        Task { await self.viewModel.search() }
      }
      self.router.present(.editTask(task, listId: task.list_id))
    }
  }

  @ViewBuilder
  private var searchResults: some View {
    if self.viewModel.isSearching {
      ProgressView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if self.viewModel.results.isEmpty, self.viewModel.hasSearched {
      ContentUnavailableView(
        "No Results",
        systemImage: DS.Icon.search,
        description: Text("No tasks found for \"\(self.viewModel.query)\"")
      )
    } else if self.viewModel.results.isEmpty {
      ContentUnavailableView(
        "Search Tasks",
        systemImage: DS.Icon.search,
        description: Text("Search by title or notes")
      )
    } else {
      List {
        ForEach(self.viewModel.groupedResults, id: \.listId) { group in
          Section {
            ForEach(group.tasks, id: \.id) { task in
              SearchResultRow(task: task)
                .contentShape(Rectangle())
                .onTapGesture {
                  HapticManager.selection()
                  self.presentTask(task)
                }
            }
          } header: {
            if let list = viewModel.lists[group.listId] {
              Button {
                HapticManager.selection()
                self.dismiss()
                self.onSelectList?(list)
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
      Image(systemName: self.task.isCompleted ? DS.Icon.circleChecked : DS.Icon.circle)
        .foregroundStyle(self.task.isCompleted ? DS.Colors.success : self.task.taskColor)
        .font(.title3)

      VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
        HStack(spacing: DS.Spacing.xs) {
          if let icon = task.taskPriority.icon {
            Image(systemName: icon)
              .foregroundStyle(self.task.taskPriority.color)
              .font(.caption)
          }

          Text(self.task.title)
            .font(.body.weight(.medium))
            .strikethrough(self.task.isCompleted)
            .foregroundStyle(self.isOverdue ? DS.Colors.overdue : .primary)

          if self.task.isStarred {
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
    .opacity(self.task.isCompleted ? 0.6 : 1.0)
  }
}
