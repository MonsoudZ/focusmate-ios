import Foundation

actor RequestContext {
    static let shared = RequestContext()

    private var latestRequestId: String?
    nonisolated(unsafe) private var latestRequestIdSnapshot: String?

    func setLatestRequestId(_ requestId: String?) {
        latestRequestId = requestId
        latestRequestIdSnapshot = requestId
    }

    func getLatestRequestId() -> String? {
        latestRequestId
    }

    nonisolated func getLatestRequestIdSync() -> String? {
        latestRequestIdSnapshot
    }
}
