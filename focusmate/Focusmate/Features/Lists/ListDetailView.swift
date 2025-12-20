import SwiftData
import SwiftUI

struct ListDetailView: View {
  let list: ListDTO
  @EnvironmentObject var appState: AppState
  @EnvironmentObject var swiftDataManager: SwiftDataManager
  @StateObject private var refreshCoordinator = RefreshCoordinator.shared
  @StateObject private var itemViewModel: ItemViewModel

  @State private var showingCreateItem = false
  @State private var showingEditList = false
  @State private var showingDeleteConfirmation = false
  @State private var showingShareList = false
  @State private var showingBatchMove = false
  @State private var showingBatchReassign = false
  @State private var showingBatchDeleteConfirmation = false
  @State private var shares: [ListShare] = []
  @Environment(\.dismiss) private var dismiss

  init(list: ListDTO, itemService: ItemService) {
    self.list = list
    let apiClient = APIClient(tokenProvider: { AppState().auth.jwt })
    _itemViewModel = StateObject(wrappedValue: ItemViewModel(
      itemService: itemService,
      swiftDataManager: SwiftDataManager.shared,
      apiClient: apiClient
    ))
  }

  var body: some View {
    VStack(spacing: 0) {
      listHeaderView
      itemsListView
      batchActionBarView
    }
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
        if self.itemViewModel.isSelectionMode {
          Button("Cancel") {
            self.itemViewModel.exitSelectionMode()
          }
        } else {
          Button("Delete List", role: .destructive) {
            self.showingDeleteConfirmation = true
          }
        }
      }

      ToolbarItem(placement: .navigationBarTrailing) {
        HStack(spacing: 8) {
          if !self.itemViewModel.isSelectionMode && !self.itemViewModel.items.isEmpty {
            Button {
              self.itemViewModel.enterSelectionMode()
            } label: {
              Image(systemName: "checkmark.circle")
            }
          }

          Button {
            self.showingCreateItem = true
          } label: {
            Image(systemName: "plus")
          }
        }
      }
    }
    .sheet(isPresented: self.$showingCreateItem) {
      CreateItemView(
        listId: self.list.id,
        itemService: ItemService(
          apiClient: self.appState.auth.api,
          swiftDataManager: SwiftDataManager.shared
        )
      )
    }
    .onReceive(refreshCoordinator.refreshPublisher) { event in
      // Automatically refresh when items are modified
      if case .items(let listId) = event, listId == self.list.id {
        Task {
          await self.itemViewModel.loadItems(listId: self.list.id)
        }
      }
    }
    .sheet(isPresented: self.$showingEditList) {
      EditListView(list: self.list, listService: ListService(apiClient: self.appState.auth.api))
    }
    .sheet(isPresented: self.$showingShareList) {
      ShareListView(list: self.list, listService: ListService(apiClient: self.appState.auth.api))
    }
    .sheet(isPresented: self.$showingBatchMove) {
      BatchMoveSheet { targetListId in
        Task {
          await self.itemViewModel.batchMove(targetListId: targetListId)
        }
      }
      .environmentObject(self.appState)
    }
    .sheet(isPresented: self.$showingBatchReassign) {
      BatchReassignSheet(listId: self.list.id) { targetUserId in
        Task {
          await self.itemViewModel.batchReassign(targetUserId: targetUserId)
        }
      }
      .environmentObject(self.appState)
    }
    .task {
      await self.itemViewModel.loadItems(listId: self.list.id)
      await self.loadShares()
    }
    .alert("Delete Tasks", isPresented: self.$showingBatchDeleteConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Delete", role: .destructive) {
        Task {
          await self.itemViewModel.batchDelete()
        }
      }
    } message: {
      Text("Are you sure you want to delete \(self.itemViewModel.selectedTaskIds.count) task(s)? This action cannot be undone.")
    }
    .alert("Delete List", isPresented: self.$showingDeleteConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Delete", role: .destructive) {
        Task {
          await self.deleteList()
        }
      }
    } message: {
      Text("Are you sure you want to delete '\(self.list.title)'? This action cannot be undone.")
    }
    .alert("Batch Operation Result", isPresented: .constant(self.itemViewModel.batchOperationResult != nil)) {
      Button("OK") {
        self.itemViewModel.batchOperationResult = nil
      }
    } message: {
      if let result = itemViewModel.batchOperationResult {
        Text(result.summaryMessage)
      }
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

  // MARK: - View Components

  private var listHeaderView: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        VStack(alignment: .leading) {
          Text(self.list.title)
            .font(.title2)
            .fontWeight(.bold)

          if let description = list.description, !description.isEmpty {
            Text(description)
              .font(.subheadline)
              .foregroundColor(.secondary)
          }
        }

        Spacer()

        HStack(spacing: 8) {
          Button("Share") {
            self.showingShareList = true
          }
          .buttonStyle(.bordered)

          Button("Edit") {
            self.showingEditList = true
          }
          .buttonStyle(.bordered)
        }
      }

      HStack {
        Label("Tasks", systemImage: "list.bullet")

        if !self.shares.isEmpty {
          Label("\(self.shares.count) shared", systemImage: "person.2")
            .foregroundColor(.blue)
        }

        Spacer()
      }
      .font(.caption)
      .foregroundColor(.secondary)
    }
    .padding()
    .background(Color(.systemGray6))
  }

  @ViewBuilder
  private var itemsListView: some View {
    if self.itemViewModel.isLoading {
      ItemsLoadingView()
    } else if self.itemViewModel.items.isEmpty {
      EmptyStateView(
        title: "No items yet",
        message: "Tap the + button to add your first item",
        icon: "checklist",
        actionTitle: "Create Item",
        action: { self.showingCreateItem = true }
      )
    } else {
      SwiftUI.List {
        ForEach(self.itemViewModel.items) { item in
          if self.itemViewModel.isSelectionMode {
            selectionModeRow(for: item)
          } else {
            normalModeRow(for: item)
          }
        }
      }
      .listStyle(.plain)
      .refreshable {
        await self.itemViewModel.loadItems(listId: self.list.id)
        await self.loadShares()
      }
    }
  }

  @ViewBuilder
  private var batchActionBarView: some View {
    if self.itemViewModel.isSelectionMode {
      BatchActionBar(
        selectedCount: self.itemViewModel.selectedTaskIds.count,
        onComplete: {
          Task {
            await self.itemViewModel.batchComplete(completed: true)
          }
        },
        onDelete: {
          self.showingBatchDeleteConfirmation = true
        },
        onMove: {
          self.showingBatchMove = true
        },
        onReassign: {
          self.showingBatchReassign = true
        },
        onCancel: {
          self.itemViewModel.exitSelectionMode()
        },
        onSelectAll: {
          self.itemViewModel.selectAll()
        },
        onDeselectAll: {
          self.itemViewModel.deselectAll()
        }
      )
    }
  }

  private func selectionModeRow(for item: Item) -> some View {
    ItemRowView(
      item: item,
      onToggleComplete: {},
      isSelectionMode: true,
      isSelected: self.itemViewModel.selectedTaskIds.contains(item.id),
      onToggleSelection: {
        self.itemViewModel.toggleTaskSelection(item.id)
      }
    )
    .contentShape(Rectangle())
    .onTapGesture {
      self.itemViewModel.toggleTaskSelection(item.id)
    }
  }

  private func normalModeRow(for item: Item) -> some View {
    NavigationLink(destination: TaskActionSheet(item: item, itemViewModel: self.itemViewModel)) {
      ItemRowView(
        item: item,
        onToggleComplete: {
          Task {
            await self.itemViewModel.completeItem(
              id: item.id,
              completed: !item.isCompleted,
              completionNotes: nil
            )
          }
        },
        isSelectionMode: false,
        isSelected: false,
        onToggleSelection: {}
      )
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      Button("Delete", role: .destructive) {
        Task {
          await self.itemViewModel.deleteItem(id: item.id)
        }
      }
    }
    .swipeActions(edge: .leading, allowsFullSwipe: true) {
      Button {
        Task {
          await self.itemViewModel.completeItem(
            id: item.id,
            completed: !item.isCompleted,
            completionNotes: nil
          )
        }
      } label: {
        Label(item.isCompleted ? "Incomplete" : "Complete", systemImage: item.isCompleted ? "arrow.uturn.backward" : "checkmark")
      }
      .tint(item.isCompleted ? .orange : .green)
    }
  }

  // MARK: - Actions

  private func deleteList() async {
    do {
      let listService = ListService(apiClient: appState.auth.api)
      try await listService.deleteList(id: self.list.id)
      self.dismiss()
    } catch {
      // Error handling could be added here if needed
    }
  }

  private func loadShares() async {
    do {
      let listService = ListService(apiClient: appState.auth.api)
      self.shares = try await listService.fetchShares(listId: self.list.id)
    } catch {
      // Silently fail - shares are not critical for list functionality
    }
  }
}

struct ItemRowView: View {
  let item: Item
  let onToggleComplete: () -> Void
  let isSelectionMode: Bool
  let isSelected: Bool
  let onToggleSelection: () -> Void

  private var isOverdue: Bool {
    guard let dueDate = item.dueDate else { return false }
    return dueDate < Date()
  }

  private var recurrenceDescription: String {
    guard let pattern = item.recurrence_pattern else { return "" }
    let interval = item.recurrence_interval

    switch pattern {
    case "daily":
      return interval == 1 ? "Daily" : "Every \(interval) days"
    case "weekly":
      if interval == 1 {
        if let days = item.recurrence_days, !days.isEmpty {
          let dayNames = days.map { dayOfWeekName($0) }.joined(separator: ", ")
          return "Weekly (\(dayNames))"
        }
        return "Weekly"
      } else {
        return "Every \(interval) weeks"
      }
    case "monthly":
      return interval == 1 ? "Monthly" : "Every \(interval) months"
    default:
      return "Recurring"
    }
  }

  private func dayOfWeekName(_ day: Int) -> String {
    switch day {
    case 0: return "Sun"
    case 1: return "Mon"
    case 2: return "Tue"
    case 3: return "Wed"
    case 4: return "Thu"
    case 5: return "Fri"
    case 6: return "Sat"
    default: return ""
    }
  }

  var body: some View {
    HStack {
      if isSelectionMode {
        // Selection checkbox in selection mode
        Button {
          onToggleSelection()
        } label: {
          Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .foregroundColor(isSelected ? .blue : .secondary)
            .font(.title2)
        }
        .buttonStyle(.plain)
      } else {
        // Completion button in normal mode
        Button {
          self.onToggleComplete()
        } label: {
          Image(systemName: self.item.isCompleted ? "checkmark.circle.fill" : "circle")
            .foregroundColor(self.item.isCompleted ? .green : .secondary)
            .font(.title2)
        }
        .buttonStyle(.plain)
      }

      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text(self.item.title)
            .fontWeight(self.item.isCompleted ? .regular : .medium)
            .strikethrough(self.item.isCompleted)
            .foregroundColor(self.isOverdue && !self.item.isCompleted ? DesignSystem.Colors.overdue : DesignSystem.Colors.textPrimary)

          if self.isOverdue, !self.item.isCompleted {
            Image(systemName: DesignSystem.Icons.taskOverdue)
              .foregroundColor(DesignSystem.Colors.overdue)
              .font(DesignSystem.Typography.caption1)
          }
        }

        if let description = item.description {
          Text(description)
            .font(.caption)
            .foregroundColor(.secondary)
        }

        HStack {
          if let dueDate = item.dueDate {
            Text(dueDate, style: .date)
              .font(.caption)
              .foregroundColor(self.isOverdue ? .red : .secondary)
          }

          // Show recurring task badge
          if self.item.is_recurring {
            DSBadge(
              self.recurrenceDescription,
              icon: DesignSystem.Icons.taskRecurring,
              color: DesignSystem.Colors.recurring
            )
          }

          // Show location-based task badge
          if self.item.location_based, let locationName = self.item.location_name {
            DSBadge(
              locationName,
              icon: DesignSystem.Icons.taskLocation,
              color: DesignSystem.Colors.location
            )
          }

          // Show subtask progress badge
          if self.item.has_subtasks && self.item.subtasks_count > 0 {
            DSBadge(
              "\(self.item.subtasks_completed_count)/\(self.item.subtasks_count)",
              icon: DesignSystem.Icons.taskSubtasks,
              color: self.item.subtasks_completed_count == self.item.subtasks_count
                ? DesignSystem.Colors.completed
                : DesignSystem.Colors.warning
            )
          }

          // Show completion details for completed tasks
          if self.item.isCompleted, let completedAt = item.completed_at {
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
              Text("Completed")
                .font(.caption2)
                .foregroundColor(.green)
                .fontWeight(.medium)

              Text(self.formatCompletionTime(completedAt))
                .font(.caption2)
                .foregroundColor(.secondary)
            }
          }
        }
      }

      Spacer()
    }
    .padding(.vertical, DesignSystem.Spacing.xs)
    .padding(.horizontal, DesignSystem.Spacing.sm)
    .background(self.isOverdue && !self.item.isCompleted ? DesignSystem.Colors.overdueLight : Color.clear)
    .overlay(
      self.isOverdue && !self.item.isCompleted ?
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
        .stroke(DesignSystem.Colors.overdue, lineWidth: 1) :
        nil
    )
    .opacity(self.item.isCompleted ? 0.6 : 1.0) // Fade out completed tasks
    .animation(.easeInOut(duration: 0.3), value: self.item.isCompleted)
    .taskAccessibility(
      title: self.item.title,
      isCompleted: self.item.isCompleted,
      dueDate: self.item.dueDate,
      isOverdue: self.isOverdue,
      hasSubtasks: self.item.has_subtasks,
      subtasksCompleted: self.item.subtasks_completed_count,
      subtasksTotal: self.item.subtasks_count,
      isSelectionMode: self.isSelectionMode
    )
  }

  // Performance: Cached date formatters to avoid recreation on every call
  private static let iso8601Formatter = ISO8601DateFormatter()
  private static let displayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
  }()

  private func formatCompletionTime(_ completedAt: String) -> String {
    if let date = Self.iso8601Formatter.date(from: completedAt) {
      return Self.displayFormatter.string(from: date)
    }
    return "Recently"
  }

  // Removed priorityColor since Item no longer has a Priority enum
}
