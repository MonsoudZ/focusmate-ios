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

struct AppleAuthRequest: Encodable {
    let idToken: String
    let name: String?
    
    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
        case name
    }
}

struct AuthSignInResponse: Decodable {
    let user: UserDTO
    let token: String
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case user, token
        case refreshToken = "refresh_token"
    }
}

struct RefreshTokenRequest: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}


struct ForgotPasswordRequest: Encodable {
    let user: User
    
    struct User: Encodable {
        let email: String
    }
    
    init(email: String) {
        self.user = User(email: email)
    }
}

// MARK: - Lists

struct CreateListRequest: Encodable {
    let list: ListData
    struct ListData: Encodable {
        let name: String
        let description: String?
        let visibility: String
        let color: String
        let tag_ids: [Int]?

        init(name: String, description: String? = nil, visibility: String = "private", color: String = "blue", tagIds: [Int] = []) {
            self.name = name
            self.description = description
            self.visibility = visibility
            self.color = color
            self.tag_ids = tagIds.isEmpty ? nil : tagIds
        }
    }
}

struct UpdateListRequest: Encodable {
    let list: ListData
    struct ListData: Encodable {
        let name: String?
        let description: String?
        let visibility: String?
        let color: String?
        let tag_ids: [Int]?
    }
}

