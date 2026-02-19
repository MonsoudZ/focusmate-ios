import SwiftUI

struct ListsView: View {
  @State private var viewModel: ListsViewModel
  @State private var searchText = ""
  @Environment(\.router) private var router

  init(
    listService: ListService,
    taskService: TaskService,
    tagService: TagService,
    inviteService: InviteService,
    friendService: FriendService
  ) {
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
      if self.viewModel.isLoading, self.viewModel.lists.isEmpty {
        ListsLoadingView()
      } else if self.viewModel.lists.isEmpty {
        ScrollView {
          VStack(spacing: DS.Spacing.xl) {
            EmptyState(
              "No lists yet",
              message: "Create a list to organize your tasks",
              icon: DS.Icon.emptyList,
              actionTitle: "Create List",
              action: { self.presentCreateList() }
            )

            DSDivider("or start from a template")

            VStack(spacing: DS.Spacing.sm) {
              ForEach(TemplateCatalog.previewTemplates()) { template in
                Button {
                  self.presentTemplatePicker()
                } label: {
                  TemplateCardView(
                    template: template,
                    isCreating: false,
                    isDisabled: false
                  )
                }
                .buttonStyle(IntentiaCardButtonStyle())
              }

              Button {
                self.presentTemplatePicker()
              } label: {
                Text("See all templates")
                  .font(DS.Typography.caption)
                  .foregroundStyle(DS.Colors.accent)
              }
              .padding(.top, DS.Spacing.xs)
            }
          }
          .padding(DS.Spacing.md)
        }
        .surfaceBackground()
      } else {
        ScrollView {
          LazyVStack(spacing: DS.Spacing.sm) {
            ForEach(self.viewModel.lists, id: \.id) { list in
              Button {
                self.router.push(.listDetail(list), in: .lists)
              } label: {
                ListRowView(list: list)
              }
              .buttonStyle(.plain)
              .contextMenu {
                if list.role == "owner" {
                  Button(role: .destructive) {
                    self.viewModel.listToDelete = list
                    self.viewModel.showingDeleteConfirmation = true
                  } label: {
                    Label("Delete List", systemImage: DS.Icon.trash)
                  }
                }
              }
              .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                if list.role == "owner" {
                  Button(role: .destructive) {
                    self.viewModel.listToDelete = list
                    self.viewModel.showingDeleteConfirmation = true
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
    .searchable(text: self.$searchText, prompt: "Search tasks...")
    .onSubmit(of: .search) {
      self.presentSearch()
    }
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Menu {
          Button {
            self.presentCreateList()
          } label: {
            Label("Create List", systemImage: DS.Icon.plus)
          }

          Button {
            self.presentTemplatePicker()
          } label: {
            Label("Start from Template", systemImage: "doc.on.doc")
          }

          Button {
            self.presentEnterInviteCode()
          } label: {
            Label("Join List", systemImage: "link.badge.plus")
          }
        } label: {
          Image(systemName: "ellipsis.circle")
        }
      }
    }
    .floatingErrorBanner(self.$viewModel.error) {
      await self.viewModel.loadLists()
    }
    .task {
      await self.viewModel.loadLists()
    }
    .refreshable {
      await self.viewModel.loadLists()
    }
    .onChange(of: self.router.activeSheet?.id) { oldId, newId in
      // Clear search text when search sheet is dismissed
      if oldId == "search", newId == nil {
        self.searchText = ""
      }
    }
    .alert("Delete List", isPresented: self.$viewModel.showingDeleteConfirmation) {
      Button("Cancel", role: .cancel) {
        self.viewModel.listToDelete = nil
      }
      Button("Delete", role: .destructive) {
        if let list = viewModel.listToDelete {
          Task { await self.viewModel.deleteList(list) }
        }
        self.viewModel.listToDelete = nil
      }
    } message: {
      Text(
        "Are you sure you want to delete '\(self.viewModel.listToDelete?.name ?? "")'? This action cannot be undone."
      )
    }
  }

  // MARK: - Sheet Presentation

  private func presentCreateList() {
    self.router.sheetCallbacks.onListCreated = {
      await self.viewModel.loadLists()
    }
    self.router.present(.createList)
  }

  private func presentTemplatePicker() {
    self.router.sheetCallbacks.onListCreated = {
      await self.viewModel.loadLists()
    }
    self.router.present(.templatePicker)
  }

  private func presentEnterInviteCode() {
    self.router.sheetCallbacks.onListJoined = { list in
      self.router.push(.listDetail(list), in: .lists)
      Task { await self.viewModel.loadLists() }
    }
    self.router.present(.enterInviteCode)
  }

  private func presentSearch() {
    self.router.present(.search(initialQuery: self.searchText))
  }
}
