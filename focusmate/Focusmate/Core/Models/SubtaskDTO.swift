import Foundation

struct SubtaskDTO: Codable, Identifiable, Hashable {
    let id: Int
    let task_id: Int?
    let title: String
    let note: String?
    let status: String?
    let completed_at: String?
    let position: Int?
    let created_at: String?

    var isCompleted: Bool {
        completed_at != nil
    }
}
