import SwiftUI

/// View builder for navigation destinations based on Route type
struct RouteDestination: View {
    let route: Route
    let appState: AppState

    var body: some View {
        switch route {
        case .listDetail(let list):
            ListDetailView(
                list: list,
                taskService: appState.taskService,
                listService: appState.listService,
                tagService: appState.tagService,
                inviteService: appState.inviteService,
                friendService: appState.friendService,
                subtaskManager: appState.subtaskManager
            )

        case .taskDetail(let task, let listName):
            TaskDetailView(
                task: task,
                listName: listName,
                onComplete: { },
                onDelete: { },
                onUpdate: { },
                taskService: appState.taskService,
                tagService: appState.tagService,
                subtaskManager: appState.subtaskManager,
                listService: appState.listService,
                listId: task.list_id
            )

        case .listInvites(let list):
            ListInvitesView(
                list: list,
                inviteService: appState.inviteService
            )

        case .notificationSettings:
            NotificationSettingsView()

        case .appBlockingSettings:
            AppBlockingSettingsView()

        #if DEBUG
        case .debugNotifications:
            DebugNotificationView()
        #endif
        }
    }
}
