import Foundation

// MARK: - Empty Response

struct EmptyResponse: Decodable {}

// MARK: - Auth

struct AuthSignInBody: Encodable {
    let user: User
    struct User: Encodable {
        let email: String
        let password: String
    }
}

struct AuthSignUpBody: Encodable {
    let user: User
    struct User: Encodable {
        let email: String
        let password: String
        let password_confirmation: String
        let name: String
        let timezone: String
    }
}

struct AuthSignInResponse: Decodable {
    let user: UserDTO
    let token: String
}

// MARK: - Lists

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

// MARK: - Tasks

struct TaskDTO: Codable, Identifiable {
    let id: Int
    let list_id: Int
    let title: String
    let note: String?
    let due_at: String?
    let completed_at: String?
    let priority: Int?
    let status: String?
    let created_at: String?
    let updated_at: String?
}

struct CreateTaskRequest: Encodable {
    let task: TaskData
    struct TaskData: Encodable {
        let title: String
        let note: String?
        let due_at: String?

        init(title: String, note: String? = nil, due_at: String? = nil) {
            self.title = title
            self.note = note
            self.due_at = due_at
        }
    }
}

struct UpdateTaskRequest: Encodable {
    let task: TaskData
    struct TaskData: Encodable {
        let title: String?
        let note: String?
        let due_at: String?
    }
}
