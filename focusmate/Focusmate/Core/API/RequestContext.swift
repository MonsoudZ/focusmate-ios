import Foundation

actor RequestContext {
    static let shared = RequestContext()

    private var latestRequestId: String?

    func setLatestRequestId(_ requestId: String?) {
        latestRequestId = requestId
    }

    func getLatestRequestId() -> String? {
        latestRequestId
    }
}
