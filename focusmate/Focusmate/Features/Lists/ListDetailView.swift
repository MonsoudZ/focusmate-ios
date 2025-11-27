import SwiftData
import SwiftUI

struct ListDetailView: View {
  let list: ListDTO
  @EnvironmentObject var appState: AppState
  @EnvironmentObject var swiftDataManager: SwiftDataManager
  // @EnvironmentObject var deltaSyncService: DeltaSyncService // Temporarily disabled
  @StateObject private var refreshCoordinator = RefreshCoordinator.shared
  @StateObject private var itemViewModel: ItemViewModel

  @State private var showingCreateItem = false
  @State private var showingEditList = false
  @State private var showingDeleteConfirmation = false
  @State private var showingShareList = false
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
      // List Header
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
          // ListDTO doesn't have overdueTasksCount field
          // if self.list.overdueTasksCount > 0 {
          //   Label("\(self.list.overdueTasksCount) overdue", systemImage: "exclamationmark.triangle")
          //     .foregroundColor(.red)
          // }
        }
        .font(.caption)
        .foregroundColor(.secondary)
      }
      .padding()
      .background(Color(.systemGray6))

      // Items List
      if self.itemViewModel.isLoading {
        ProgressView("Loading items...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if self.itemViewModel.items.isEmpty {
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
            ForEach(self.itemViewModel.items) { item in
              NavigationLink(destination: TaskActionSheet(item: item, itemViewModel: self.itemViewModel)) {
                ItemRowView(item: item) {
                  Task {
                    await self.itemViewModel.completeItem(
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
                let item = self.itemViewModel.items[index]
                Task {
                  await self.itemViewModel.deleteItem(id: item.id)
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
          self.showingDeleteConfirmation = true
        }
      }

      ToolbarItem(placement: .navigationBarTrailing) {
        Button {
          self.showingCreateItem = true
        } label: {
          Image(systemName: "plus")
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
    .task {
      await self.itemViewModel.loadItems(listId: self.list.id)
      await self.loadShares()
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

  private func deleteList() async {
    do {
      let listService = ListService(apiClient: appState.auth.api)
      try await listService.deleteList(id: self.list.id)
      #if DEBUG
      print("✅ ListDetailView: Deleted list \(self.list.title) (ID: \(self.list.id))")
      #endif
      self.dismiss() // Navigate back to lists view
    } catch {
      #if DEBUG
      print("❌ ListDetailView: Failed to delete list: \(error)")
      #endif
      // You could add error handling here if needed
    }
  }

  private func loadShares() async {
    do {
      let listService = ListService(apiClient: appState.auth.api)
      self.shares = try await listService.fetchShares(listId: self.list.id)
      #if DEBUG
      print("✅ ListDetailView: Loaded \(self.shares.count) shares for list \(self.list.id)")
      #endif
    } catch {
      #if DEBUG
      print("❌ ListDetailView: Failed to load shares: \(error)")
      #endif
    }
  }
}

struct ItemRowView: View {
  let item: Item
  let onToggleComplete: () -> Void

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
      Button {
        self.onToggleComplete()
      } label: {
        Image(systemName: self.item.isCompleted ? "checkmark.circle.fill" : "circle")
          .foregroundColor(self.item.isCompleted ? .green : .secondary)
          .font(.title2)
      }
      .buttonStyle(.plain)

      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text(self.item.title)
            .fontWeight(self.item.isCompleted ? .regular : .medium)
            .strikethrough(self.item.isCompleted)
            .foregroundColor(self.isOverdue && !self.item.isCompleted ? .red : .primary)

          if self.isOverdue, !self.item.isCompleted {
            Image(systemName: "exclamationmark.triangle.fill")
              .foregroundColor(.red)
              .font(.caption)
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
            HStack(spacing: 2) {
              Image(systemName: "repeat")
                .font(.caption2)
              Text(self.recurrenceDescription)
                .font(.caption2)
            }
            .foregroundColor(.blue)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.blue.opacity(0.1))
            .clipShape(Capsule())
          }

          // Show location-based task badge
          if self.item.location_based, let locationName = self.item.location_name {
            HStack(spacing: 2) {
              Image(systemName: "location.fill")
                .font(.caption2)
              Text(locationName)
                .font(.caption2)
                .lineLimit(1)
            }
            .foregroundColor(.purple)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.purple.opacity(0.1))
            .clipShape(Capsule())
          }

          // Show subtask progress badge
          if self.item.has_subtasks && self.item.subtasks_count > 0 {
            HStack(spacing: 2) {
              Image(systemName: "checklist")
                .font(.caption2)
              Text("\(self.item.subtasks_completed_count)/\(self.item.subtasks_count)")
                .font(.caption2)
            }
            .foregroundColor(self.item.subtasks_completed_count == self.item.subtasks_count ? .green : .orange)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background((self.item.subtasks_completed_count == self.item.subtasks_count ? Color.green : Color.orange).opacity(0.1))
            .clipShape(Capsule())
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
    .padding(.vertical, 4)
    .padding(.horizontal, 8)
    .background(self.isOverdue && !self.item.isCompleted ? Color.red.opacity(0.1) : Color.clear)
    .overlay(
      self.isOverdue && !self.item.isCompleted ?
        RoundedRectangle(cornerRadius: 6)
        .stroke(Color.red, lineWidth: 1) :
        nil
    )
    .opacity(self.item.isCompleted ? 0.6 : 1.0) // Fade out completed tasks
    .animation(.easeInOut(duration: 0.3), value: self.item.isCompleted)
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
