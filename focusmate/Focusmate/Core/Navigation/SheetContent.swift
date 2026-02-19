import SwiftUI

/// View builder for sheet content based on Sheet type
struct SheetContent: View {
  let sheet: Sheet
  let appState: AppState

  @Environment(\.dismiss) private var dismiss
  @Environment(\.router) private var router

  var body: some View {
    switch self.sheet {
    // MARK: - Today Tab Sheets

    case .quickAddTask:
      QuickAddTaskView(
        listService: self.appState.listService,
        taskService: self.appState.taskService,
        onTaskCreated: {
          await self.router.sheetCallbacks.onTaskCreated?()
        }
      )

    case let .taskDetail(task, listName):
      TaskDetailView(
        task: task,
        listName: listName,
        onComplete: {
          await self.router.sheetCallbacks.onTaskCompleted?(task)
        },
        onDelete: {
          await self.router.sheetCallbacks.onTaskDeleted?(task)
        },
        onUpdate: {
          await self.router.sheetCallbacks.onTaskUpdated?()
        },
        taskService: self.appState.taskService,
        tagService: self.appState.tagService,
        subtaskManager: self.appState.subtaskManager,
        listService: self.appState.listService,
        listId: task.list_id
      )

    case let .addSubtask(parentTask):
      AddSubtaskSheet(parentTask: parentTask) { title in
        await self.router.sheetCallbacks.onSubtaskCreated?(parentTask, title)
      }

    case let .editSubtask(info):
      EditSubtaskSheet(subtask: info.subtask) { newTitle in
        await self.router.sheetCallbacks.onSubtaskUpdated?(info, newTitle)
      }

    // MARK: - Lists Tab Sheets

    case .templatePicker:
      TemplatePickerView(
        listService: self.appState.listService,
        taskService: self.appState.taskService,
        onCreated: { list in
          Task { await self.router.sheetCallbacks.onListCreated?() }
          self.router.navigateToList(list)
        }
      )

    case .createList:
      CreateListView(listService: self.appState.listService, tagService: self.appState.tagService)

    case let .editList(list):
      EditListView(list: list, listService: self.appState.listService, tagService: self.appState.tagService)

    case .enterInviteCode:
      EnterInviteCodeView(
        inviteService: self.appState.inviteService,
        onAccepted: { list in
          self.router.sheetCallbacks.onListJoined?(list)
          self.router.navigateToList(list)
        }
      )

    case let .acceptInvite(code):
      AcceptInviteView(
        code: code,
        inviteService: self.appState.inviteService,
        onAccepted: { list in
          self.router.sheetCallbacks.onListJoined?(list)
          self.router.navigateToList(list)
          self.router.switchTab(to: .lists)
        }
      )
      .environment(self.appState.auth)

    case let .search(initialQuery):
      SearchView(
        taskService: self.appState.taskService,
        listService: self.appState.listService,
        tagService: self.appState.tagService,
        onSelectList: { list in
          self.router.navigateToList(list)
        },
        initialQuery: initialQuery
      )

    case let .listMembers(list):
      ListMembersView(
        list: list,
        apiClient: self.appState.auth.api,
        inviteService: self.appState.inviteService,
        friendService: self.appState.friendService
      )

    case let .createTask(listId):
      CreateTaskView(
        listId: listId,
        taskService: self.appState.taskService,
        tagService: self.appState.tagService
      )

    case let .editTask(task, listId):
      EditTaskView(
        listId: listId,
        task: task,
        taskService: self.appState.taskService,
        tagService: self.appState.tagService,
        onSave: self.router.sheetCallbacks.onTaskSaved
      )

    case .createTag:
      CreateTagView(tagService: self.appState.tagService) { _ in
        Task { await self.router.sheetCallbacks.onTagCreated?() }
      }

    case let .overdueReason(task):
      OverdueReasonSheet(task: task) { reason in
        self.router.sheetCallbacks.onOverdueReasonSubmitted?(reason)
      }

    case let .rescheduleTask(task):
      RescheduleSheet(task: task) { newDate, reason in
        await self.router.sheetCallbacks.onRescheduleSubmitted?(newDate, reason)
      }

    case let .taskDeepLink(taskId):
      TaskDeepLinkView(
        taskId: taskId,
        taskService: self.appState.taskService,
        tagService: self.appState.tagService,
        subtaskManager: self.appState.subtaskManager,
        listService: self.appState.listService
      )

    case let .inviteMember(list):
      InviteMemberView(
        list: list,
        apiClient: self.appState.auth.api,
        onInvited: {
          self.router.sheetCallbacks.onMemberInvited?()
        }
      )

    case let .createInviteLink(list):
      CreateInviteView(
        viewModel: ListInvitesViewModel(list: list, inviteService: self.appState.inviteService)
      ) { invite in
        self.router.sheetCallbacks.onInviteCreated?(invite)
      }

    case let .shareInvite(invite):
      ShareInviteSheet(invite: invite)

    // MARK: - Settings Tab Sheets

    case let .editProfile(user):
      EditProfileView(user: user, apiClient: self.appState.auth.api)

    case .changePassword:
      ChangePasswordView(apiClient: self.appState.auth.api)

    case .deleteAccount:
      DeleteAccountView(apiClient: self.appState.auth.api, authStore: self.appState.auth)

    // MARK: - Auth Sheets

    case .register:
      RegisterView()

    case .forgotPassword:
      ForgotPasswordView()

    case .preAuthInviteCode:
      PreAuthInviteCodeView(
        code: .constant(""),
        onCodeEntered: { code in
          self.router.sheetCallbacks.onPreAuthInviteCodeEntered?(code)
          self.router.dismissSheet()
        }
      )
    }
  }
}
