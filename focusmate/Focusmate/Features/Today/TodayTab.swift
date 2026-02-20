import SwiftUI

/// Tab wrapper for Today view with NavigationStack
struct TodayTab: View {
  @Environment(\.router) private var router
  @Environment(AppState.self) var appState

  let onOverdueCountChange: ((Int) -> Void)?

  var body: some View {
    NavigationStack(path: Binding(
      get: { self.router.todayPath },
      set: { self.router.todayPath = $0 }
    )) {
      TodayView(
        taskService: self.appState.taskService,
        listService: self.appState.listService,
        tagService: self.appState.tagService,
        apiClient: self.appState.auth.api,
        subtaskManager: self.appState.subtaskManager,
        onOverdueCountChange: self.onOverdueCountChange
      )
      .navigationDestination(for: Route.self) { route in
        RouteDestination(route: route, appState: self.appState)
      }
    }
  }
}
