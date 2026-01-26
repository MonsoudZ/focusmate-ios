import SwiftUI

struct ListsView: View {
    @EnvironmentObject var state: AppState
    @State private var showingCreateList = false
    @State private var showingSearch = false
    @State private var showingDeleteConfirmation = false
    @State private var listToDelete: ListDTO?
    @State private var lists: [ListDTO] = []
    @State private var isLoading = false
    @State private var error: FocusmateError?
    @State private var selectedList: ListDTO?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && lists.isEmpty {
                    ListsLoadingView()
                } else if lists.isEmpty {
                    EmptyStateView(
                        title: "No lists yet",
                        message: "Create a list to organize your tasks",
                        icon: DS.Icon.emptyList,
                        actionTitle: "Create List",
                        action: { showingCreateList = true }
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: DS.Spacing.sm) {
                            ForEach(lists, id: \.id) { list in
                                NavigationLink(destination: ListDetailView(
                                    list: list,
                                    taskService: state.taskService,
                                    listService: state.listService,
                                    tagService: state.tagService
                                )) {
                                    ListRowView(list: list)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    if list.role == "owner" || list.role == nil {
                                        Button(role: .destructive) {
                                            listToDelete = list
                                            showingDeleteConfirmation = true
                                        } label: {
                                            Label("Delete List", systemImage: DS.Icon.trash)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(DS.Spacing.md)
                    }
                }
            }
            .navigationTitle("Lists")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: DS.Spacing.md) {
                        Button {
                            showingSearch = true
                        } label: {
                            Image(systemName: DS.Icon.search)
                        }
                        
                        Button {
                            showingCreateList = true
                        } label: {
                            Image(systemName: DS.Icon.plus)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCreateList) {
                CreateListView(listService: state.listService)
            }
            .sheet(isPresented: $showingSearch) {
                SearchView(
                    taskService: state.taskService,
                    listService: state.listService,
                    tagService: state.tagService,
                    onSelectList: { list in
                        selectedList = list
                    }
                )
            }
            .navigationDestination(item: $selectedList) { list in
                ListDetailView(
                    list: list,
                    taskService: state.taskService,
                    listService: state.listService,
                    tagService: state.tagService
                )
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
            .alert("Delete List", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    listToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let list = listToDelete {
                        Task { await deleteList(list) }
                    }
                    listToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete '\(listToDelete?.name ?? "")'? This action cannot be undone.")
            }
            .onChange(of: showingCreateList) { _, isPresented in
                if !isPresented {
                    Task { await loadLists() }
                }
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
