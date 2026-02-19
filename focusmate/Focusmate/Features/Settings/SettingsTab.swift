import SwiftUI

/// Tab wrapper for Settings view with NavigationStack
struct SettingsTab: View {
  @Environment(\.router) private var router
  @EnvironmentObject var appState: AppState

  var body: some View {
    NavigationStack(path: Binding(
      get: { self.router.settingsPath },
      set: { self.router.settingsPath = $0 }
    )) {
      SettingsView()
        .navigationDestination(for: Route.self) { route in
          RouteDestination(route: route, appState: self.appState)
        }
    }
  }
}
