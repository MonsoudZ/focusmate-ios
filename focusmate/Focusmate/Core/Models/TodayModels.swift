import Foundation

struct TodayResponse: Codable {
    let overdue: [TaskDTO]
    let due_today: [TaskDTO]
    let completed_today: [TaskDTO]
    let stats: TodayStats?
    let streak: StreakInfo?
}

struct TodayStats: Codable {
    let overdue_count: Int?
    let due_today_count: Int?
    let completed_today_count: Int?
}

struct StreakInfo: Codable {
    let current: Int
    let longest: Int
}
