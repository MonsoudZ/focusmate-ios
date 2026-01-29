import SwiftUI

struct ListsView: View {
    @StateObject private var viewModel: ListsViewModel
    @State private var searchText = ""
    @State private var showingEnterInviteCode = false

    init(listService: ListService, taskService: TaskService, tagService: TagService, inviteService: InviteService, friendService: FriendService) {
        _viewModel = StateObject(wrappedValue: ListsViewModel(
            listService: listService,
            taskService: taskService,
            tagService: tagService,
            inviteService: inviteService,
            friendService: friendService
        ))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.lists.isEmpty {
                    ListsLoadingView()
                } else if viewModel.lists.isEmpty {
                    EmptyStateView(
                        title: "No lists yet",
                        message: "Create a list to organize your tasks",
                        icon: DS.Icon.emptyList,
                        actionTitle: "Create List",
                        action: { viewModel.showingCreateList = true }
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: DS.Spacing.sm) {
                            ForEach(viewModel.lists, id: \.id) { list in
                                NavigationLink(destination: ListDetailView(
                                    list: list,
                                    taskService: viewModel.taskService,
                                    listService: viewModel.listService,
                                    tagService: viewModel.tagService,
                                    inviteService: viewModel.inviteService,
                                    friendService: viewModel.friendService
                                )) {
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
                viewModel.showingSearch = true
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            viewModel.showingCreateList = true
                        } label: {
                            Label("Create List", systemImage: DS.Icon.plus)
                        }

                        Button {
                            showingEnterInviteCode = true
                        } label: {
                            Label("Join List", systemImage: "link.badge.plus")
                        }
                    } label: {
                        Image(systemName: DS.Icon.plus)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingCreateList) {
                CreateListView(listService: viewModel.listService)
            }
            .sheet(isPresented: $showingEnterInviteCode) {
                EnterInviteCodeView(
                    inviteService: viewModel.inviteService,
                    onAccepted: { list in
                        viewModel.selectedList = list
                        Task { await viewModel.loadLists() }
                    }
                )
            }
            .sheet(isPresented: $viewModel.showingSearch) {
                SearchView(
                    taskService: viewModel.taskService,
                    listService: viewModel.listService,
                    tagService: viewModel.tagService,
                    onSelectList: { list in
                        viewModel.selectedList = list
                    },
                    initialQuery: searchText
                )
            }
            .onChange(of: viewModel.showingSearch) { _, isShowing in
                if !isShowing {
                    searchText = ""
                }
            }
            .navigationDestination(item: $viewModel.selectedList) { list in
                ListDetailView(
                    list: list,
                    taskService: viewModel.taskService,
                    listService: viewModel.listService,
                    tagService: viewModel.tagService,
                    inviteService: viewModel.inviteService,
                    friendService: viewModel.friendService
                )
            }
            .errorBanner($viewModel.error) {
                Task { await viewModel.loadLists() }
            }
            .task {
                await viewModel.loadLists()
            }
            .refreshable {
                await viewModel.loadLists()
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
            .onChange(of: viewModel.showingCreateList) { _, isPresented in
                if !isPresented {
                    Task { await viewModel.loadLists() }
                }
            }
        }
    }
}
