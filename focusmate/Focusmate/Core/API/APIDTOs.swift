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
