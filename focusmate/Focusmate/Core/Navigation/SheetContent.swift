import SwiftUI

/// View builder for sheet content based on Sheet type
struct SheetContent: View {
    let sheet: Sheet
    let appState: AppState

    @Environment(\.dismiss) private var dismiss
    @Environment(\.router) private var router

    var body: some View {
        switch sheet {
        // MARK: - Today Tab Sheets
        case .quickAddTask:
            QuickAddTaskView(
                listService: appState.listService,
                taskService: appState.taskService,
                onTaskCreated: {
                    await router.sheetCallbacks.onTaskCreated?()
                }
            )

        case .taskDetail(let task, let listName):
            TaskDetailView(
                task: task,
                listName: listName,
                onComplete: {
                    await router.sheetCallbacks.onTaskCompleted?(task)
                },
                onDelete: {
                    await router.sheetCallbacks.onTaskDeleted?(task)
                },
                onUpdate: {
                    await router.sheetCallbacks.onTaskUpdated?()
                },
                taskService: appState.taskService,
                tagService: appState.tagService,
                subtaskManager: appState.subtaskManager,
                listService: appState.listService,
                listId: task.list_id
            )

        case .addSubtask(let parentTask):
            AddSubtaskSheet(parentTask: parentTask) { title in
                await router.sheetCallbacks.onSubtaskCreated?(parentTask, title)
            }

        case .editSubtask(let info):
            EditSubtaskSheet(subtask: info.subtask) { newTitle in
                await router.sheetCallbacks.onSubtaskUpdated?(info, newTitle)
            }

        // MARK: - Lists Tab Sheets
        case .templatePicker:
            TemplatePickerView(
                listService: appState.listService,
                taskService: appState.taskService,
                onCreated: { list in
                    Task { await router.sheetCallbacks.onListCreated?() }
                    router.navigateToList(list)
                }
            )

        case .createList:
            CreateListView(listService: appState.listService, tagService: appState.tagService)

        case .editList(let list):
            EditListView(list: list, listService: appState.listService, tagService: appState.tagService)

        case .enterInviteCode:
            EnterInviteCodeView(
                inviteService: appState.inviteService,
                onAccepted: { list in
                    router.sheetCallbacks.onListJoined?(list)
                    router.navigateToList(list)
                }
            )

        case .acceptInvite(let code):
            AcceptInviteView(
                code: code,
                inviteService: appState.inviteService,
                onAccepted: { list in
                    router.sheetCallbacks.onListJoined?(list)
                    router.navigateToList(list)
                    router.switchTab(to: .lists)
                }
            )
            .environmentObject(appState.auth)

        case .search(let initialQuery):
            SearchView(
                taskService: appState.taskService,
                listService: appState.listService,
                tagService: appState.tagService,
                onSelectList: { list in
                    router.navigateToList(list)
                },
                initialQuery: initialQuery
            )

        case .listMembers(let list):
            ListMembersView(
                list: list,
                apiClient: appState.auth.api,
                inviteService: appState.inviteService,
                friendService: appState.friendService
            )

        case .createTask(let listId):
            CreateTaskView(
                listId: listId,
                taskService: appState.taskService,
                tagService: appState.tagService
            )

        case .editTask(let task, let listId):
            EditTaskView(
                listId: listId,
                task: task,
                taskService: appState.taskService,
                tagService: appState.tagService,
                onSave: router.sheetCallbacks.onTaskSaved
            )

        case .createTag:
            CreateTagView(tagService: appState.tagService) { _ in
                Task { await router.sheetCallbacks.onTagCreated?() }
            }

        case .overdueReason(let task):
            OverdueReasonSheet(task: task) { reason in
                router.sheetCallbacks.onOverdueReasonSubmitted?(reason)
            }

        case .rescheduleTask(let task):
            RescheduleSheet(task: task) { newDate, reason in
                await router.sheetCallbacks.onRescheduleSubmitted?(newDate, reason)
            }

        case .taskDeepLink(let taskId):
            TaskDeepLinkView(
                taskId: taskId,
                taskService: appState.taskService,
                tagService: appState.tagService,
                subtaskManager: appState.subtaskManager,
                listService: appState.listService
            )

        case .inviteMember(let list):
            InviteMemberView(
                list: list,
                apiClient: appState.auth.api,
                onInvited: {
                    router.sheetCallbacks.onMemberInvited?()
                }
            )

        case .createInviteLink(let list):
            CreateInviteView(
                viewModel: ListInvitesViewModel(list: list, inviteService: appState.inviteService)
            ) { invite in
                router.sheetCallbacks.onInviteCreated?(invite)
            }

        case .shareInvite(let invite):
            ShareInviteSheet(invite: invite)

        // MARK: - Settings Tab Sheets
        case .editProfile(let user):
            EditProfileView(user: user, apiClient: appState.auth.api)

        case .changePassword:
            ChangePasswordView(apiClient: appState.auth.api)

        case .deleteAccount:
            DeleteAccountView(apiClient: appState.auth.api, authStore: appState.auth)

        // MARK: - Auth Sheets
        case .register:
            RegisterView()

        case .forgotPassword:
            ForgotPasswordView()

        case .preAuthInviteCode:
            PreAuthInviteCodeView(
                code: .constant(""),
                onCodeEntered: { code in
                    router.sheetCallbacks.onPreAuthInviteCodeEntered?(code)
                    router.dismissSheet()
                }
            )
        }
    }
}
