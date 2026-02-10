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
        guard auth.jwt != nil else { return }
        // Serialize concurrent invocations from multiple .task modifiers.
        // Since AppBootstrapper is @MainActor, this flag check is thread-safe.
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        // ✅ Always track per-run (not persisted)
        if !hasTrackedInitialOpenThisRun {
            hasTrackedInitialOpenThisRun = true
            await trackAppOpenedIfAuthenticated()
        }

        // ✅ One-time authenticated boot (persisted)
        guard !settings.didCompleteAuthenticatedBoot else { return }

        // All permissions (notifications, screen time, calendar) are now
        // handled by the onboarding flow (OnboardingPermissionsPage).

        _ = EscalationService.shared

        // ✅ Mark completion only after we've run everything
        settings.didCompleteAuthenticatedBoot = true
    }

    func handleBecameActive() async {
        await trackAppOpenedIfAuthenticated()
    }

    /// Call this on sign-out so a new session (or new user) can run boot again.
    func resetAuthenticatedBootState() {
        settings.didCompleteAuthenticatedBoot = false
        hasTrackedInitialOpenThisRun = false
    }

    private func trackAppOpenedIfAuthenticated() async {
        guard auth.jwt != nil else { return }

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        do {
            _ = try await auth.api.request(
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
