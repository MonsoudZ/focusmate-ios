import Foundation

struct TaskDTO: Codable, Identifiable {
    let id: Int
    let list_id: Int
    let title: String
    let notes: String?
    let visibility: Bool
    let completed_at: String?
    let updated_at: String?
    let deleted_at: String?

    enum CodingKeys: String, CodingKey {
        case id, list_id, title, visibility
        case notes = "note"
        case completed_at, updated_at, deleted_at
    }
}

struct Page<T: Codable>: Codable {
    let data: [T]
    let next_cursor: String?
}

struct AuthSignInBody: Encodable {
    let authentication: Auth
    struct Auth: Encodable { 
        let email: String
        let password: String 
    }
}

struct AuthSignUpBody: Encodable {
    let authentication: Auth
    struct Auth: Encodable { 
        let email: String
        let password: String
        let password_confirmation: String
        let name: String 
    }
}

struct AuthSignInResponse: Decodable { 
    let user: UserDTO
    let token: String 
}

struct DeviceTokenBody: Encodable { 
    let device: Device
    struct Device: Encodable { 
        let platform: String
        let token: String 
    } 
}

struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    init(_ wrapped: Encodable) { self.encodeFunc = wrapped.encode }
    func encode(to encoder: Encoder) throws { try encodeFunc(encoder) }
}

struct Empty: Decodable {}

// MARK: - Request Models

struct CreateListRequest: Encodable {
    let list: ListData
    struct ListData: Encodable {
        let name: String
        let description: String?
        let visibility: String

        init(name: String, description: String? = nil, visibility: String = "private") {
            self.name = name
            self.description = description
            self.visibility = visibility
        }
    }
}

struct UpdateListRequest: Encodable {
    let list: ListData
    struct ListData: Encodable {
        let name: String?
        let description: String?
        let visibility: String?
    }
}

struct CreateTaskRequest: Encodable {
    let task: TaskData
    struct TaskData: Encodable {
        let title: String
        let notes: String?
        let visibility: String
        let due_at: String?
        let strict_mode: Bool

        enum CodingKeys: String, CodingKey {
            case title, notes, visibility, due_at, strict_mode
        }

        init(title: String, notes: String? = nil, visibility: String = "private_task", due_at: String? = nil, strict_mode: Bool = false) {
            self.title = title
            self.notes = notes
            self.visibility = visibility
            self.due_at = due_at
            self.strict_mode = strict_mode
        }
    }
}

// Helper enum for type safety
enum TaskVisibility: String {
    case visibleToAll = "visible_to_all"
    case privateTask = "private_task"
    case hiddenFromCoaches = "hidden_from_coaches"
    case coachingOnly = "coaching_only"
}

struct UpdateTaskRequest: Encodable {
    let task: TaskData
    struct TaskData: Encodable {
        let title: String?
        let notes: String?
        let visibility: String?
    }
}

struct ReassignTaskRequest: Encodable {
    let task: TaskData
    struct TaskData: Encodable {
        let assignee_id: String
    }
}
