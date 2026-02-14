import Foundation

extension Date {
  /// Returns the next whole hour from the current time.
  /// At 9:15 → 10:00. At 14:00 → 15:00. At 23:15 → 00:00 tomorrow.
  static func nextWholeHour() -> Date {
    let calendar = Calendar.current
    let now = Date()
    let components = calendar.dateComponents([.minute, .second], from: now)
    let minutesToAdd = 60 - (components.minute ?? 0)
    return calendar.date(byAdding: .minute, value: minutesToAdd, to: now)?
      .addingTimeInterval(-Double(components.second ?? 0)) ?? now
  }
}
