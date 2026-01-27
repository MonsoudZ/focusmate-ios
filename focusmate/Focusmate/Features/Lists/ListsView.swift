import SwiftUI

struct ListsView: View {
    @StateObject private var viewModel: ListsViewModel

    init(listService: ListService, taskService: TaskService, tagService: TagService) {
        _viewModel = StateObject(wrappedValue: ListsViewModel(
            listService: listService,
            taskService: taskService,
            tagService: tagService
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
                                    tagService: viewModel.tagService
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
                            viewModel.showingSearch = true
                        } label: {
                            Image(systemName: DS.Icon.search)
                        }

                        Button {
                            viewModel.showingCreateList = true
                        } label: {
                            Image(systemName: DS.Icon.plus)
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingCreateList) {
                CreateListView(listService: viewModel.listService)
            }
            .sheet(isPresented: $viewModel.showingSearch) {
                SearchView(
                    taskService: viewModel.taskService,
                    listService: viewModel.listService,
                    tagService: viewModel.tagService,
                    onSelectList: { list in
                        viewModel.selectedList = list
                    }
                )
            }
            .navigationDestination(item: $viewModel.selectedList) { list in
                ListDetailView(
                    list: list,
                    taskService: viewModel.taskService,
                    listService: viewModel.listService,
                    tagService: viewModel.tagService
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
