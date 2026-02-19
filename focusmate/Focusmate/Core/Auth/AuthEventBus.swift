import Combine
import Foundation

enum AuthEvent: Equatable, Sendable {
  case unauthorized
  case signedIn
  case signedOut
  case tokenUpdated(hasToken: Bool)
}

/// Thread-safe event bus for authentication-related events.
///
/// This class is intentionally not actor-isolated to provide a synchronous API,
/// allowing it to be called from property observers and other sync contexts.
/// Thread safety is guaranteed via internal locking for mutable state, and
/// `PassthroughSubject.send()` is documented as thread-safe by Apple.
final class AuthEventBus: @unchecked Sendable {
  static let shared = AuthEventBus()

  var publisher: AnyPublisher<AuthEvent, Never> {
    self.subject.eraseToAnyPublisher()
  }

  private let subject = PassthroughSubject<AuthEvent, Never>()
  private var lastUnauthorizedAt: Date?
  private let lock = NSLock()

  init() {}

  /// Send an event to all subscribers. Thread-safe, can be called from any context.
  /// Unauthorized events are throttled to max 1 per second to prevent cascading logouts.
  func send(_ event: AuthEvent) {
    if event == .unauthorized {
      self.lock.lock()
      let now = Date()
      let shouldThrottle = self.lastUnauthorizedAt.map { now.timeIntervalSince($0) < 1.0 } ?? false
      if !shouldThrottle {
        self.lastUnauthorizedAt = now
      }
      self.lock.unlock()

      if shouldThrottle { return }
    }
    self.subject.send(event)
  }

  #if DEBUG
    /// Test hook: clears throttle state so `.unauthorized` events are not dropped in fast test runs.
    func _resetThrottleForTests() {
      self.lock.lock()
      self.lastUnauthorizedAt = nil
      self.lock.unlock()
    }
  #endif
}
