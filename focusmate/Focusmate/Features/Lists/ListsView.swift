import SwiftData
import SwiftUI

struct ListsView: View {
  @EnvironmentObject var state: AppState
  @EnvironmentObject var swiftDataManager: SwiftDataManager
  // @EnvironmentObject var deltaSyncService: DeltaSyncService // Temporarily disabled
  @StateObject private var refreshCoordinator = RefreshCoordinator.shared
  @State private var showingCreateList = false
  @State private var lists: [ListDTO] = []
  @State private var isLoading = false
  @State private var error: FocusmateError?

  var body: some View {
    NavigationStack {
      VStack {
        if self.isLoading {
          ProgressView("Loading lists...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if self.lists.isEmpty {
          VStack(spacing: 16) {
            Image(systemName: "list.bullet")
              .font(.system(size: 48))
              .foregroundColor(.secondary)

            Text("No lists yet")
              .font(.title3)
              .fontWeight(.medium)

            Text("Tap the + button to create your first list")
              .font(.subheadline)
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          ScrollView {
            LazyVStack(spacing: 8) {
              ForEach(self.lists, id: \.id) { list in
                NavigationLink(destination: ListDetailView(
                  list: list,
                  itemService: ItemService(
                    apiClient: self.state.auth.api,
                    swiftDataManager: SwiftDataManager.shared
                  )
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
            .padding()
          }
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
              print("🔄 ListsView: Sign out button tapped")
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
        CreateListView(listService: ListService(apiClient: self.state.auth.api))
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
      .alert("Error", isPresented: .constant(self.error != nil)) {
        Button("OK") {
          self.error = nil
        }
      } message: {
        if let error {
          Text(error.errorDescription ?? "An error occurred")
        }
      }
    }
  }

  private func loadLists() async {
    self.isLoading = true
    self.error = nil

    do {
      // Use existing API client with token from AuthStore
      let listService = ListService(apiClient: state.auth.api)
      self.lists = try await listService.fetchLists()

      print("✅ ListsView: Loaded \(self.lists.count) lists from API")
      print("📋 ListsView: List IDs: \(self.lists.map(\.id))")
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      print("❌ ListsView: Failed to load lists: \(error)")
    }

    self.isLoading = false
  }

  private func deleteList(_ list: ListDTO) async {
    do {
      // Use existing API client with token from AuthStore
      let listService = ListService(apiClient: state.auth.api)
      try await listService.deleteList(id: list.id)

      // Remove from local array
      self.lists.removeAll { $0.id == list.id }
      print("✅ ListsView: Deleted list \(list.title) (ID: \(list.id))")
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      print("❌ ListsView: Failed to delete list: \(error)")
    }
  }
}
