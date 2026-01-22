import Combine
import Foundation
import SwiftUI
import UIKit
import UserNotifications

@MainActor
final class AppBootstrapper: ObservableObject {

    private let auth: AuthStore
    private let settings = AppSettings.shared

    private var hasTrackedInitialOpenThisRun = false

    init(auth: AuthStore) {
        self.auth = auth
    }

    func runAuthenticatedBootTasksIfNeeded() async {
        guard auth.jwt != nil else { return }

        // ✅ Always track per-run (not persisted)
        if !hasTrackedInitialOpenThisRun {
            hasTrackedInitialOpenThisRun = true
            await trackAppOpenedIfAuthenticated()
        }

        // ✅ One-time authenticated boot (persisted)
        guard !settings.didCompleteAuthenticatedBoot else { return }

        await requestPushPermissionOnceIfNeeded()

        if !settings.didRequestNotificationsPermission {
            _ = await NotificationService.shared.requestPermission()
            settings.didRequestNotificationsPermission = true
        }

        if !settings.didRequestCalendarPermission {
            _ = await CalendarService.shared.requestPermission()
            settings.didRequestCalendarPermission = true
        }

        if !settings.didRequestScreenTimePermission {
            do {
                try await ScreenTimeService.shared.requestAuthorization()
            } catch {
                Logger.debug("Screen Time authorization failed: \(error)", category: .general)
            }
            settings.didRequestScreenTimePermission = true
        }

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

    private func requestPushPermissionOnceIfNeeded() async {
        guard !settings.didRequestPushPermission else { return }

        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            settings.didRequestPushPermission = true

            if granted {
                Logger.info("Push notification permission granted", category: .general)
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                Logger.info("Push notification permission denied", category: .general)
            }
        } catch {
            Logger.error("Failed to request push permission: \(error)", category: .general)
        }
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
