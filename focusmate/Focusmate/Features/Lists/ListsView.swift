import SwiftData
import SwiftUI

struct ListsView: View {
  @EnvironmentObject var state: AppState
  @EnvironmentObject var swiftDataManager: SwiftDataManager
  @StateObject private var refreshCoordinator = RefreshCoordinator.shared
  @State private var showingCreateList = false
  @State private var lists: [ListDTO] = []
  @State private var isLoading = false
  @State private var error: FocusmateError?

  var body: some View {
    NavigationStack {
      VStack {
        if self.isLoading {
          ListsLoadingView()
        } else if self.lists.isEmpty {
          EmptyStateView(
            title: "No lists yet",
            message: "Tap the + button to create your first list",
            icon: "list.bullet",
            actionTitle: "Create List",
            action: { self.showingCreateList = true }
          )
        } else {
          SwiftUI.List {
            ForEach(self.lists, id: \.id) { list in
              NavigationLink(destination: ListDetailView(
                list: list,
                itemService: self.state.itemService
              )) {
                ListRowView(list: list)
              }
              .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button("Delete", role: .destructive) {
                  Task {
                    await self.deleteList(list)
                  }
                }
              }
            }
          }
          .listStyle(.plain)
        }
      }
      .navigationTitle("Lists")
      .safeAreaInset(edge: .bottom) {
        SyncStatusView()
      }
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Sign Out") {
            Task {
              await self.state.auth.signOut()
              Logger.debug("Sign out button tapped", category: .ui)
            }
          }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            self.showingCreateList = true
          } label: {
            Image(systemName: "plus")
          }
        }
      }
      .sheet(isPresented: self.$showingCreateList) {
        CreateListView(listService: self.state.listService)
      }
      .onReceive(refreshCoordinator.refreshPublisher) { event in
        // Automatically refresh when refresh event is triggered
        if case .lists = event {
          Task {
            await self.loadLists()
          }
        }
      }
      .task {
        await self.loadLists()
      }
      .refreshable {
        await self.loadLists()
      }
      .errorBanner(error: self.$error) {
        await self.loadLists()
      }
    }
  }

  private func loadLists() async {
    self.isLoading = true
    self.error = nil

    do {
      // Performance: Use AppState's shared listService instead of creating new instance
      self.lists = try await self.state.listService.fetchLists()
    } catch {
      self.error = ErrorHandler.shared.handle(error)
    }

    self.isLoading = false
  }

  private func deleteList(_ list: ListDTO) async {
    // Optimistically remove from UI
    let originalLists = self.lists
    self.lists.removeAll { $0.id == list.id }

    do {
      // Performance: Use AppState's shared listService instead of creating new instance
      try await self.state.listService.deleteList(id: list.id)
      Logger.info("Successfully deleted list \(list.id)", category: .database)
    } catch {
      // If deletion failed, restore the list
      self.lists = originalLists
      self.error = ErrorHandler.shared.handle(error, context: "Delete List")
      Logger.error("Failed to delete list \(list.id)", error: error, category: .database)
    }
  }
}
