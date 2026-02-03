import SwiftUI

struct ListsView: View {
    @State private var viewModel: ListsViewModel
    @State private var searchText = ""
    @Environment(\.router) private var router

    init(listService: ListService, taskService: TaskService, tagService: TagService, inviteService: InviteService, friendService: FriendService) {
        _viewModel = State(initialValue: ListsViewModel(
            listService: listService,
            taskService: taskService,
            tagService: tagService,
            inviteService: inviteService,
            friendService: friendService
        ))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.lists.isEmpty {
                ListsLoadingView()
            } else if viewModel.lists.isEmpty {
                EmptyState(
                    "No lists yet",
                    message: "Create a list to organize your tasks",
                    icon: DS.Icon.emptyList,
                    actionTitle: "Create List",
                    action: { presentCreateList() }
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.sm) {
                        ForEach(viewModel.lists, id: \.id) { list in
                            Button {
                                router.push(.listDetail(list), in: .lists)
                            } label: {
                                ListRowView(list: list)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if list.role == "owner" || list.role == nil {
                                    Button(role: .destructive) {
                                        viewModel.listToDelete = list
                                        viewModel.showingDeleteConfirmation = true
                                    } label: {
                                        Label("Delete List", systemImage: DS.Icon.trash)
                                    }
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if list.role == "owner" || list.role == nil {
                                    Button(role: .destructive) {
                                        viewModel.listToDelete = list
                                        viewModel.showingDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: DS.Icon.trash)
                                    }
                                }
                            }
                        }
                    }
                    .padding(DS.Spacing.md)
                }
                .surfaceBackground()
            }
        }
        .navigationTitle("Lists")
        .searchable(text: $searchText, prompt: "Search tasks...")
        .onSubmit(of: .search) {
            presentSearch()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        presentCreateList()
                    } label: {
                        Label("Create List", systemImage: DS.Icon.plus)
                    }

                    Button {
                        presentEnterInviteCode()
                    } label: {
                        Label("Join List", systemImage: "link.badge.plus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .floatingErrorBanner($viewModel.error) {
            await viewModel.loadLists()
        }
        .task {
            await viewModel.loadLists()
        }
        .refreshable {
            await viewModel.loadLists()
        }
        .onChange(of: router.activeSheet?.id) { oldId, newId in
            // Clear search text when search sheet is dismissed
            if oldId == "search" && newId == nil {
                searchText = ""
            }
        }
        .alert("Delete List", isPresented: $viewModel.showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                viewModel.listToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let list = viewModel.listToDelete {
                    Task { await viewModel.deleteList(list) }
                }
                viewModel.listToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete '\(viewModel.listToDelete?.name ?? "")'? This action cannot be undone.")
        }
    }

    // MARK: - Sheet Presentation

    private func presentCreateList() {
        router.sheetCallbacks.onListCreated = {
            await viewModel.loadLists()
        }
        router.present(.createList)
    }

    private func presentEnterInviteCode() {
        router.sheetCallbacks.onListJoined = { list in
            router.push(.listDetail(list), in: .lists)
            Task { await viewModel.loadLists() }
        }
        router.present(.enterInviteCode)
    }

    private func presentSearch() {
        router.present(.search(initialQuery: searchText))
    }
}
