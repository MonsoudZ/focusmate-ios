import SwiftUI

/// View builder for navigation destinations based on Route type
struct RouteDestination: View {
  let route: Route
  let appState: AppState

  var body: some View {
    switch self.route {
    case let .listDetail(list):
      ListDetailView(
        list: list,
        taskService: self.appState.taskService,
        listService: self.appState.listService,
        tagService: self.appState.tagService,
        inviteService: self.appState.inviteService,
        friendService: self.appState.friendService,
        subtaskManager: self.appState.subtaskManager
      )

    case let .taskDetail(task, listName):
      TaskDetailView(
        task: task,
        listName: listName,
        onComplete: {},
        onDelete: {},
        onUpdate: {},
        taskService: self.appState.taskService,
        tagService: self.appState.tagService,
        subtaskManager: self.appState.subtaskManager,
        listService: self.appState.listService,
        listId: task.list_id
      )

    case let .listInvites(list):
      ListInvitesView(
        list: list,
        inviteService: self.appState.inviteService
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
