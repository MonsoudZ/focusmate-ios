import Foundation

struct UserDTO: Codable, Identifiable, Hashable {
    let id: Int
    let email: String
    let name: String?
    let role: String
    let timezone: String?
    let hasPassword: Bool?

    enum CodingKeys: String, CodingKey {
        case id, email, name, role, timezone
        case hasPassword = "has_password"
    }
}
