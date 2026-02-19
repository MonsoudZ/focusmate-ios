import Foundation

/// All sheet types in the app
enum Sheet: Identifiable {
  // MARK: - Today Tab Sheets

  case quickAddTask
  case taskDetail(TaskDTO, listName: String)
  case addSubtask(TaskDTO)
  case editSubtask(SubtaskEditInfo)

  // MARK: - Lists Tab Sheets

  case templatePicker
  case createList
  case editList(ListDTO)
  case enterInviteCode
  case acceptInvite(String)
  case search(initialQuery: String)
  case listMembers(ListDTO)
  case createTask(listId: Int)

  // MARK: - Task Sheets

  case editTask(TaskDTO, listId: Int)
  case createTag
  case overdueReason(TaskDTO)
  case rescheduleTask(TaskDTO)
  case taskDeepLink(Int)

  // MARK: - Invite Sheets

  case inviteMember(ListDTO)
  case createInviteLink(ListDTO)
  case shareInvite(InviteDTO)

  // MARK: - Settings Tab Sheets

  case editProfile(UserDTO)
  case changePassword
  case deleteAccount

  // MARK: - Auth Sheets

  case register
  case forgotPassword
  case preAuthInviteCode

  // MARK: - Identifiable

  var id: String {
    switch self {
    case .quickAddTask:
      return "quickAddTask"
    case let .taskDetail(task, _):
      return "taskDetail-\(task.id)"
    case let .addSubtask(task):
      return "addSubtask-\(task.id)"
    case let .editSubtask(info):
      return "editSubtask-\(info.subtask.id)"
    case .templatePicker:
      return "templatePicker"
    case .createList:
      return "createList"
    case let .editList(list):
      return "editList-\(list.id)"
    case .enterInviteCode:
      return "enterInviteCode"
    case let .acceptInvite(code):
      return "acceptInvite-\(code)"
    case .search:
      return "search"
    case let .listMembers(list):
      return "listMembers-\(list.id)"
    case let .createTask(listId):
      return "createTask-\(listId)"
    case let .editTask(task, _):
      return "editTask-\(task.id)"
    case .createTag:
      return "createTag"
    case let .overdueReason(task):
      return "overdueReason-\(task.id)"
    case let .rescheduleTask(task):
      return "rescheduleTask-\(task.id)"
    case let .taskDeepLink(taskId):
      return "taskDeepLink-\(taskId)"
    case let .inviteMember(list):
      return "inviteMember-\(list.id)"
    case let .createInviteLink(list):
      return "createInviteLink-\(list.id)"
    case let .shareInvite(invite):
      return "shareInvite-\(invite.id)"
    case let .editProfile(user):
      return "editProfile-\(user.id)"
    case .changePassword:
      return "changePassword"
    case .deleteAccount:
      return "deleteAccount"
    case .register:
      return "register"
    case .forgotPassword:
      return "forgotPassword"
    case .preAuthInviteCode:
      return "preAuthInviteCode"
    }
  }
}
