import Foundation

actor RequestContext {
  static let shared = RequestContext()

  private var latestRequestId: String?

  func setLatestRequestId(_ requestId: String?) {
    self.latestRequestId = requestId
  }

  func getLatestRequestId() -> String? {
    self.latestRequestId
  }
}
