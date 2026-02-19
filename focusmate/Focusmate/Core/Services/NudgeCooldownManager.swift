import Foundation

/// Tracks per-task nudge cooldowns to avoid hitting the server's 10-minute
/// rate limit. Stores cooldown timestamps in memory — intentionally NOT
/// persisted to disk so a force-quit resets the state (server still enforces).
@MainActor
final class NudgeCooldownManager {
    static let shared = NudgeCooldownManager()

    private static let cooldownSeconds: TimeInterval = 600 // 10 minutes

    /// taskId → last successful nudge timestamp
    private var cooldowns: [Int: Date] = [:]

    private init() {}

    func isOnCooldown(taskId: Int) -> Bool {
        guard let lastNudge = cooldowns[taskId] else { return false }
        return Date().timeIntervalSince(lastNudge) < Self.cooldownSeconds
    }

    func remainingSeconds(taskId: Int) -> Int {
        guard let lastNudge = cooldowns[taskId] else { return 0 }
        let elapsed = Date().timeIntervalSince(lastNudge)
        let remaining = Self.cooldownSeconds - elapsed
        return remaining > 0 ? Int(ceil(remaining)) : 0
    }

    func recordNudge(taskId: Int) {
        cooldowns[taskId] = Date()
    }

    func remainingFormatted(taskId: Int) -> String? {
        let secs = remainingSeconds(taskId: taskId)
        guard secs > 0 else { return nil }
        let mins = secs / 60
        if mins > 0 {
            return "\(mins)m"
        }
        return "\(secs)s"
    }
}
