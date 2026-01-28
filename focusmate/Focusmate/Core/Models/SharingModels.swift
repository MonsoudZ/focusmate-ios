import Foundation

struct ListShare: Codable, Identifiable {
    let id: Int
    let list_id: Int
    let user_id: Int?
    let role: String
    let user: UserDTO?
    let created_at: String?
    let updated_at: String?
}

struct ShareListRequest: Codable {
    let email: String
    let role: String
}

struct ShareListResponse: Codable {
    let id: Int
    let list_id: Int
    let role: String
    let user: UserDTO?
}
