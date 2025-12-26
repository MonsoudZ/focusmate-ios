import SwiftUI

struct ListsView: View {
    @EnvironmentObject var state: AppState
    @State private var showingCreateList = false
    @State private var lists: [ListDTO] = []
    @State private var isLoading = false
    @State private var error: FocusmateError?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && lists.isEmpty {
                    ListsLoadingView()
                } else if lists.isEmpty {
                    EmptyStateView(
                        title: "No lists yet",
                        message: "Tap the + button to create your first list",
                        icon: DesignSystem.Icons.list,
                        actionTitle: "Create List",
                        action: { showingCreateList = true }
                    )
                } else {
                    List {
                        ForEach(lists, id: \.id) { list in
                            NavigationLink(destination: ListDetailView(
                                list: list,
                                taskService: state.taskService,
                                listService: state.listService
                            )) {
                                ListRowView(list: list)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", role: .destructive) {
                                    Task { await deleteList(list) }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Lists")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Sign Out") {
                        Task { await state.auth.signOut() }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateList = true
                    } label: {
                        Image(systemName: DesignSystem.Icons.add)
                    }
                }
            }
            .sheet(isPresented: $showingCreateList) {
                CreateListView(listService: state.listService)
            }
            .errorBanner($error) {
                Task { await loadLists() }
            }
            .task {
                await loadLists()
            }
            .refreshable {
                await loadLists()
            }
        }
    }

    private func loadLists() async {
        isLoading = true
        error = nil

        do {
            lists = try await state.listService.fetchLists()
        } catch let err as FocusmateError {
            error = err
        } catch {
            self.error = ErrorHandler.shared.handle(error)
        }

        isLoading = false
    }

    private func deleteList(_ list: ListDTO) async {
        let originalLists = lists
        lists.removeAll { $0.id == list.id }

        do {
            try await state.listService.deleteList(id: list.id)
        } catch {
            lists = originalLists
            self.error = ErrorHandler.shared.handle(error, context: "Delete List")
        }
    }
}
