import SwiftUI

/// Tab wrapper for Lists view with NavigationStack
struct ListsTab: View {
  @Environment(\.router) private var router
  @EnvironmentObject var appState: AppState

  var body: some View {
    NavigationStack(path: Binding(
      get: { self.router.listsPath },
      set: { self.router.listsPath = $0 }
    )) {
      ListsView(
        listService: self.appState.listService,
        taskService: self.appState.taskService,
        tagService: self.appState.tagService,
        inviteService: self.appState.inviteService,
        friendService: self.appState.friendService
      )
      .navigationDestination(for: Route.self) { route in
        RouteDestination(route: route, appState: self.appState)
      }
    }
  }
}
