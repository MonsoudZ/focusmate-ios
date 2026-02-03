import SwiftUI

/// Tab wrapper for Today view with NavigationStack
struct TodayTab: View {
    @Environment(\.router) private var router
    @EnvironmentObject var appState: AppState

    let onOverdueCountChange: ((Int) -> Void)?

    var body: some View {
        NavigationStack(path: Binding(
            get: { router.todayPath },
            set: { router.todayPath = $0 }
        )) {
            TodayView(
                taskService: appState.taskService,
                listService: appState.listService,
                tagService: appState.tagService,
                apiClient: appState.auth.api,
                subtaskManager: appState.subtaskManager,
                onOverdueCountChange: onOverdueCountChange
            )
            .navigationDestination(for: Route.self) { route in
                RouteDestination(route: route, appState: appState)
            }
        }
    }
}
