import Foundation

/// All sheet types in the app
enum Sheet: Identifiable {
    // MARK: - Today Tab Sheets
    case quickAddTask
    case taskDetail(TaskDTO, listName: String)
    case addSubtask(TaskDTO)
    case editSubtask(SubtaskEditInfo)

    // MARK: - Lists Tab Sheets
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
        case .taskDetail(let task, _):
            return "taskDetail-\(task.id)"
        case .addSubtask(let task):
            return "addSubtask-\(task.id)"
        case .editSubtask(let info):
            return "editSubtask-\(info.subtask.id)"
        case .createList:
            return "createList"
        case .editList(let list):
            return "editList-\(list.id)"
        case .enterInviteCode:
            return "enterInviteCode"
        case .acceptInvite(let code):
            return "acceptInvite-\(code)"
        case .search:
            return "search"
        case .listMembers(let list):
            return "listMembers-\(list.id)"
        case .createTask(let listId):
            return "createTask-\(listId)"
        case .editTask(let task, _):
            return "editTask-\(task.id)"
        case .createTag:
            return "createTag"
        case .overdueReason(let task):
            return "overdueReason-\(task.id)"
        case .inviteMember(let list):
            return "inviteMember-\(list.id)"
        case .createInviteLink(let list):
            return "createInviteLink-\(list.id)"
        case .shareInvite(let invite):
            return "shareInvite-\(invite.id)"
        case .editProfile(let user):
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
