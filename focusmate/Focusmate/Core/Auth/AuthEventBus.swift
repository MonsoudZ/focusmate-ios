import Combine
import Foundation

enum AuthEvent: Equatable {
    case unauthorized
    case signedIn
    case signedOut
    case tokenUpdated(hasToken: Bool)
}

@MainActor
final class AuthEventBus {
    static let shared = AuthEventBus()

    var publisher: AnyPublisher<AuthEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    private let subject = PassthroughSubject<AuthEvent, Never>()
    private var lastUnauthorizedAt: Date?

    nonisolated init() {}

    func send(_ event: AuthEvent) {
        if event == .unauthorized {
            let now = Date()
            if let last = lastUnauthorizedAt, now.timeIntervalSince(last) < 1.0 { return }
            lastUnauthorizedAt = now
        }
        subject.send(event)
    }

    #if DEBUG
    /// Test/support hook: clears throttle state so `.unauthorized` events are not dropped in fast test runs.
    func _resetThrottleForTests() {
        lastUnauthorizedAt = nil
    }
    #endif
}
