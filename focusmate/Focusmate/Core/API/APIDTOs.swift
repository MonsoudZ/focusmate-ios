import Foundation

struct TaskDTO: Codable, Identifiable {
    let id: String
    let list_id: String
    let title: String
    let notes: String?
    let visibility: String
    let completed_at: String?
    let updated_at: String?
    let deleted_at: String?
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
        let title: String
        let visibility: String
    }
}

struct UpdateListRequest: Encodable {
    let list: ListData
    struct ListData: Encodable {
        let title: String?
        let visibility: String?
    }
}

struct CreateTaskRequest: Encodable {
    let task: TaskData
    struct TaskData: Encodable {
        let title: String
        let notes: String?
        let visibility: String
    }
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
