import Foundation

/// Closure-based in-memory mutation queue for offline support.
///
/// ## System Design: Store-and-Forward with Closures
/// When a mutation fails due to no connectivity, the ViewModel enqueues a closure
/// that captures the exact service call. On reconnect, closures replay sequentially.
///
/// ## Why closures instead of Codable payloads?
/// The previous design serialized mutation parameters to UserDefaults and used a
/// replay handler switch-case to reconstruct API calls. This created a circular
/// re-enqueue bug: services caught offline errors and enqueued, but the replay
/// handler called those same services, causing re-enqueue on retry failure.
///
/// Moving offline handling to ViewModels and using closures eliminates:
/// - The MutationType enum (16 cases, only 8 actually replayed)
/// - The MutationPayloads file (13 Codable structs)
/// - The 60-line replay switch-case in AppState
/// - The circular re-enqueue bug entirely
///
/// ## Tradeoff: No Persistence
/// Closures can't be serialized, so mutations are lost on app kill. But optimistic
/// UI state is also lost on app kill — the user sees correct server state on relaunch.
/// No inconsistency arises because both local UI and pending mutations reset together.
actor MutationQueue {
  static let shared = MutationQueue()
  private static let maxRetries = 3

  struct PendingMutation: Identifiable {
    let id = UUID()
    let description: String
    let operation: @Sendable () async throws -> Void
    var retryCount: Int = 0
  }

  private var pending: [PendingMutation] = []
  private var isFlushing = false

  private init() {}

  // MARK: - Public API

  var pendingCount: Int { pending.count }

  func enqueue(description: String, operation: @escaping @Sendable () async throws -> Void) {
    let mutation = PendingMutation(description: description, operation: operation)
    pending.append(mutation)
    let count = pendingCount
    Logger.info("MutationQueue: Enqueued — \(description) (\(count) pending)", category: .api)
    Task { @MainActor in NetworkMonitor.shared.pendingMutationCount = count }
  }

  /// Replays all pending mutations sequentially.
  /// Called automatically on network reconnect via NetworkMonitor.
  ///
  /// Stops on offline error (will retry on next reconnect).
  /// Drops mutations after maxRetries non-offline failures.
  func flush() async {
    guard !isFlushing, !pending.isEmpty else { return }

    isFlushing = true
    defer { isFlushing = false }

    Logger.info("MutationQueue: Flushing \(pendingCount) pending mutations", category: .api)

    var completed: [UUID] = []

    for i in pending.indices {
      do {
        try await pending[i].operation()
        completed.append(pending[i].id)
        Logger.info("MutationQueue: Replayed — \(pending[i].description)", category: .api)
      } catch {
        pending[i].retryCount += 1

        if NetworkMonitor.isOfflineError(error) {
          Logger.info("MutationQueue: Still offline — stopping flush", category: .api)
          break
        }

        if pending[i].retryCount >= Self.maxRetries {
          completed.append(pending[i].id)
          Logger.warning(
            "MutationQueue: Dropped after \(Self.maxRetries) retries — \(pending[i].description): \(error)",
            category: .api
          )
        }
      }
    }

    pending.removeAll { mutation in completed.contains(mutation.id) }
    let count = pendingCount
    Task { @MainActor in NetworkMonitor.shared.pendingMutationCount = count }

    if pending.isEmpty {
      Logger.info("MutationQueue: All mutations flushed successfully", category: .api)
    }
  }

  /// Remove all pending mutations (e.g. on sign-out)
  func clearAll() {
    pending.removeAll()
    Task { @MainActor in NetworkMonitor.shared.pendingMutationCount = 0 }
  }
}
