import Foundation

struct TodayResponse: Codable {
  var overdue: [TaskDTO]
  let has_more_overdue: Bool?
  var due_today: [TaskDTO]
  var completed_today: [TaskDTO]
  let stats: TodayStats?
  let streak: StreakInfo?
}

struct TodayStats: Codable {
  let overdue_count: Int?
  let due_today_count: Int?
  let completed_today_count: Int?
  let remaining_today: Int?
  let completion_percentage: Int?

  /// Backend sends total_due_today / completed_today but iOS code
  /// references due_today_count / completed_today_count.  CodingKeys
  /// bridges the two so JSON decoding and local construction both work.
  enum CodingKeys: String, CodingKey {
    case overdue_count
    case due_today_count = "total_due_today"
    case completed_today_count = "completed_today"
    case remaining_today
    case completion_percentage
  }
}

struct StreakInfo: Codable {
  let current: Int
  let longest: Int
}
