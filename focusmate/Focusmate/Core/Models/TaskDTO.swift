import Foundation

struct TaskDTO: Codable {
    let id: Int
    let list_id: Int
    let title: String
    let note: String?
    let due_at: String?
    let status: String
    let strict_mode: Bool
    let updated_at: String
}


