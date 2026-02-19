import Combine
import Foundation
import SwiftUI

@MainActor
final class AppBootstrapper: ObservableObject {
  private let auth: AuthStore
  private let settings = AppSettings.shared

  private var hasTrackedInitialOpenThisRun = false
  private var isRunning = false

  init(auth: AuthStore) {
    self.auth = auth
  }

  func runAuthenticatedBootTasksIfNeeded() async {
    guard self.auth.jwt != nil else { return }
    // Serialize concurrent invocations from multiple .task modifiers.
    // Since AppBootstrapper is @MainActor, this flag check is thread-safe.
    guard !self.isRunning else { return }
    self.isRunning = true
    defer { isRunning = false }

    // ✅ Always track per-run (not persisted)
    if !self.hasTrackedInitialOpenThisRun {
      self.hasTrackedInitialOpenThisRun = true
      await self.trackAppOpenedIfAuthenticated()
    }

    // ✅ One-time authenticated boot (persisted)
    guard !self.settings.didCompleteAuthenticatedBoot else { return }

    // All permissions (notifications, screen time, calendar) are now
    // handled by the onboarding flow (OnboardingPermissionsPage).

    _ = EscalationService.shared

    // ✅ Mark completion only after we've run everything
    self.settings.didCompleteAuthenticatedBoot = true
  }

  func handleBecameActive() async {
    // Re-check FamilyControls authorization on every foreground transition.
    // Users can revoke Screen Time permissions in Settings → Screen Time at
    // any time.  Without this check the app would continue showing "blocking
    // enabled" in the UI while the OS silently ignores the ManagedSettings
    // store writes — a silent failure that leads to confused users reporting
    // "blocking doesn't work."  Reading AuthorizationCenter.authorizationStatus
    // is a synchronous property read (no IPC), so there's no performance cost.
    ScreenTimeService.shared.updateAuthorizationStatus()

    // If authorization was revoked while we had active escalation, reset.
    // This must run AFTER updateAuthorizationStatus() so isAuthorized reflects
    // the current OS state, not the stale cached value.
    EscalationService.shared.checkAuthorizationRevocation()

    await self.trackAppOpenedIfAuthenticated()
  }

  /// Call this on sign-out so a new session (or new user) can run boot again.
  func resetAuthenticatedBootState() {
    self.settings.didCompleteAuthenticatedBoot = false
    self.hasTrackedInitialOpenThisRun = false
  }

  private func trackAppOpenedIfAuthenticated() async {
    guard self.auth.jwt != nil else { return }

    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    do {
      _ = try await self.auth.api.request(
        "POST",
        "/api/v1/analytics/app_opened",
        body: AppOpenedRequest(platform: "ios", version: version)
      ) as EmptyResponse
    } catch {
      Logger.debug("Failed to track app opened: \(error)", category: .api)
    }
  }
}

private struct AppOpenedRequest: Encodable {
  let platform: String
  let version: String?
}
