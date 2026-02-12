import Foundation
import Network

/// Monitors network connectivity using NWPathMonitor.
///
/// ## System Design: Event-Driven Connectivity Detection
/// NWPathMonitor registers a callback with the OS network stack. When the network
/// interface state changes (WiFi disconnect, cellular handoff, airplane mode), the OS
/// fires the callback on a dedicated DispatchQueue. This avoids polling overhead —
/// we get O(1) notification instead of O(n) periodic checks.
///
/// ## Tradeoff
/// NWPathMonitor runs a background DispatchQueue (~1-2MB stack overhead per thread).
/// Worth it for instant reconnection detection vs polling, which would add latency
/// proportional to the poll interval and waste CPU cycles when nothing changes.
@MainActor @Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private(set) var isConnected = true
    /// Pending mutation count, updated by MutationQueue after enqueue/flush.
    /// Exposed here (rather than on MutationQueue actor) because @Observable
    /// drives SwiftUI updates — the view reads this directly.
    var pendingMutationCount = 0

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.focusmate.networkmonitor")

    private init() {}

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasConnected = self.isConnected
                self.isConnected = path.status == .satisfied

                // On reconnect, flush any queued mutations
                if !wasConnected && self.isConnected {
                    Logger.info("Network reconnected — flushing mutation queue", category: .api)
                    await MutationQueue.shared.flush()
                }
            }
        }
        monitor.start(queue: queue)
    }

    /// Check if an error represents an offline condition.
    /// Nonisolated because it's a pure function (no mutable state) and needs
    /// to be callable from any actor context (e.g. MutationQueue actor).
    nonisolated static func isOfflineError(_ error: Error) -> Bool {
        if let apiError = error as? APIError {
            switch apiError {
            case .noInternetConnection:
                return true
            case .network(let underlying):
                if let urlError = underlying as? URLError {
                    return urlError.code == .notConnectedToInternet
                        || urlError.code == .networkConnectionLost
                }
                return false
            default:
                return false
            }
        }

        if let focusmateError = error as? FocusmateError {
            switch focusmateError {
            case .noInternetConnection:
                return true
            case .network(let underlying):
                if let urlError = underlying as? URLError {
                    return urlError.code == .notConnectedToInternet
                        || urlError.code == .networkConnectionLost
                }
                return false
            default:
                return false
            }
        }

        if let urlError = error as? URLError {
            return urlError.code == .notConnectedToInternet
                || urlError.code == .networkConnectionLost
        }

        return false
    }
}
