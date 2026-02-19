import Foundation

/// Protocol abstracting ScreenTimeService so EscalationService and ViewModels
/// can be tested without importing FamilyControls (which crashes in the test runner).
@MainActor
protocol ScreenTimeManaging: AnyObject {
  var isAuthorized: Bool { get }
  var isBlocking: Bool { get }
  var hasSelections: Bool { get }
  func startBlocking()
  func stopBlocking()
  func requestAuthorization() async throws
  func updateAuthorizationStatus()
}
