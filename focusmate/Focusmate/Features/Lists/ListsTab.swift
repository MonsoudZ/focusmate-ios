import SwiftUI

/// Tab wrapper for Lists view with NavigationStack
struct ListsTab: View {
    @Environment(\.router) private var router
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack(path: Binding(
            get: { router.listsPath },
            set: { router.listsPath = $0 }
        )) {
            ListsView(
                listService: appState.listService,
                taskService: appState.taskService,
                tagService: appState.tagService,
                inviteService: appState.inviteService,
                friendService: appState.friendService
            )
            .navigationDestination(for: Route.self) { route in
                RouteDestination(route: route, appState: appState)
            }
        }
    }
}
