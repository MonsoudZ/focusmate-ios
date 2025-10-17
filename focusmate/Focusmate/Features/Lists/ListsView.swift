import SwiftUI

struct ListsView: View {
    @EnvironmentObject var state: AppState
    @State private var showingCreateList = false
    @State private var lists: [ListDTO] = []
    @State private var isLoading = false
    @State private var error: FocusmateError?

    var body: some View {
        let _ = print("📋 ListsView body rendered")
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading lists...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if lists.isEmpty {
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
                    List(lists) { list in
                        NavigationLink(destination: ListDetailView(list: list, itemService: ItemService(apiClient: state.auth.api))) {
                            ListRowView(list: list)
                        }
                    }
                }
            }
            .navigationTitle("Lists")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Sign Out") { 
                        Task { 
                            await state.auth.signOut()
                            print("🔄 ListsView: Sign out button tapped")
                        } 
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateList = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateList) {
                CreateListView(listService: ListService(apiClient: state.auth.api))
            }
            .task { 
                await loadLists()
            }
            .alert("Error", isPresented: .constant(error != nil)) {
                Button("OK") {
                    error = nil
                }
            } message: {
                if let error = error {
                    Text(error.errorDescription ?? "An error occurred")
                }
            }
        }
    }
    
    private func loadLists() async {
        isLoading = true
        error = nil
        
        do {
            let listService = ListService(apiClient: state.auth.api)
            lists = try await listService.fetchLists()
            print("✅ ListsView: Loaded \(lists.count) lists")
            print("📋 ListsView: List IDs: \(lists.map { $0.id })")
        } catch {
            self.error = ErrorHandler.shared.handle(error)
            print("❌ ListsView: Failed to load lists: \(error)")
        }
        
        isLoading = false
    }
}


