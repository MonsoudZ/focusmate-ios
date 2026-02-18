import Combine
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    let auth: AuthStore

    @Published var isLoading = false
    @Published var error: FocusmateError?

    /// Invite code entered before sign-in, to be auto-accepted after authentication
    @Published var pendingInviteCode: String?
    /// List the user just joined via invite (for navigation after accept)
    @Published var joinedList: ListDTO?

    private var cancellables = Set<AnyCancellable>()

    // Services
    private(set) lazy var listService = ListService(apiClient: auth.api)
    private(set) lazy var taskService = TaskService(
        apiClient: auth.api,
        sideEffects: TaskSideEffectHandler(notificationService: .shared, calendarService: .shared)
    )
    private(set) lazy var deviceService = DeviceService(apiClient: auth.api)
    private(set) lazy var tagService = TagService(apiClient: auth.api)
    private(set) lazy var inviteService = InviteService(apiClient: auth.api)
    private(set) lazy var friendService = FriendService(apiClient: auth.api)
    private(set) lazy var subtaskManager = SubtaskManager(taskService: taskService)

    // Push token coordination (grouped for atomic consistency)
    private struct PushTokenState {
        var lastKnownToken: String?
        var lastRegisteredToken: String?
        var hasRegistered = false
        var isRegistering = false
    }
    private var pushState = PushTokenState()

    init(auth: AuthStore) {
        self.auth = auth

        SentryService.shared.initialize()
        NetworkMonitor.shared.start()

        // React to auth lifecycle events.
        //
        // Previously this used auth.objectWillChange (Combine bridge) which fired on
        // every @Published change — including isLoading toggles that were no-ops.
        // With AuthStore migrated to @Observable, we use AuthEventBus which is more
        // targeted: we only react to meaningful auth transitions.
        AuthEventBus.shared.publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self else { return }
                switch event {
                case .signedIn, .tokenUpdated(hasToken: true):
                    Task {
                        await self.tryRegisterDeviceIfPossible()
                        await self.tryAcceptPendingInvite()
                        await self.syncTimezoneIfNeeded()
                    }
                case .signedOut:
                    Task { await ResponseCache.shared.invalidateAll() }
                    AppSettings.shared.didCompleteAuthenticatedBoot = false
                    AppSettings.shared.hasCompletedOnboarding = false
                default:
                    break
                }
            }
            .store(in: &cancellables)

        // Listen for push token updates
        NotificationCenter.default.publisher(for: .didReceivePushToken)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self else { return }
                if let token = notification.userInfo?["token"] as? String {
                    self.pushState.lastKnownToken = token
                    Task { await self.tryRegisterDeviceIfPossible() }
                }
            }
            .store(in: &cancellables)

        // Sync device timezone to server when the system timezone changes at
        // runtime (e.g. user crosses a timezone boundary or changes Settings).
        // Without this, the server continues filtering "today" using the stale
        // timezone stored at signup — producing wrong results until the user
        // manually edits their profile.
        NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task {
                    await self.syncTimezoneIfNeeded()
                    await ResponseCache.shared.invalidate("today")
                }
            }
            .store(in: &cancellables)

        // If AppDelegate already has a token, stash it immediately.
        pushState.lastKnownToken = AppDelegate.pushToken

        // NOTE: Do NOT flush pending notification routes here.
        // AppState.init() runs during StateObject creation, before RootView's
        // .onReceive listeners are set up. Flushing here would post to
        // NotificationCenter with no subscribers, losing the route.
        // Instead, RootView calls flushPendingRouteIfAny() in .onAppear.

        // Try immediately in case we're already logged in.
        Task { await tryRegisterDeviceIfPossible() }
    }

    private func tryRegisterDeviceIfPossible() async {
        guard auth.jwt != nil else { return }
        guard !pushState.isRegistering else { return }

        let tokenToRegister = pushState.lastKnownToken

        // Skip if we already registered with this exact token.
        // Use a separate flag to ensure we register at least once per session
        // even when push permission is denied (token is nil).
        if pushState.hasRegistered && pushState.lastRegisteredToken == tokenToRegister {
            return
        }

        pushState.isRegistering = true
        defer { pushState.isRegistering = false }

        do {
            _ = try await deviceService.registerDevice(pushToken: tokenToRegister)
            pushState.lastRegisteredToken = tokenToRegister
            pushState.hasRegistered = true
            Logger.info("Device registered successfully (push: \(tokenToRegister != nil))", category: .api)
        } catch {
            Logger.warning("Device registration skipped: \(error)", category: .api)
        }
    }

    func clearError() {
        error = nil
    }

    /// Accepts a pending invite code after the user signs in.
    ///
    /// Called from the AuthEventBus subscriber on `.signedIn` and
    /// `.tokenUpdated` events.  Three outcomes:
    ///
    /// 1. **Success** — code cleared, won't retry.
    /// 2. **Transient failure** (offline / 5xx) — code preserved, retries
    ///    automatically on the next auth event.
    /// 3. **Permanent failure** (4xx — expired, invalid, already used) — code
    ///    cleared, error shown once, won't retry.
    private var isAcceptingInvite = false

    private func tryAcceptPendingInvite() async {
        guard auth.jwt != nil else { return }
        guard let code = pendingInviteCode else { return }
        guard !isAcceptingInvite else { return }

        isAcceptingInvite = true
        defer { isAcceptingInvite = false }

        do {
            let response = try await inviteService.acceptInvite(code: code)
            pendingInviteCode = nil
            joinedList = response.list
            Logger.info("Auto-accepted pending invite for list: \(response.list.name)", category: .api)
        } catch where NetworkMonitor.isOfflineError(error) {
            // Transient — preserve code for automatic retry
            Logger.warning("Invite accept deferred (offline): \(error)", category: .api)
        } catch {
            // Permanent — clear code to stop retrying
            pendingInviteCode = nil
            Logger.warning("Failed to auto-accept pending invite: \(error)", category: .api)
            self.error = ErrorHandler.shared.handle(error, context: "Accept Invite")
        }
    }

    // MARK: - Timezone Sync

    /// Fire-and-forget PATCH to keep the server's timezone in sync with the device.
    ///
    /// **Why this matters at the data layer:** The `GET /api/v1/today` endpoint
    /// computes bucket boundaries (overdue / due_today / completed_today) using
    /// `users.timezone`.  When that column is stale — say the user flew from
    /// New York to Los Angeles but the server still says `America/New_York` — the
    /// server's "start of today" is 3 hours ahead of reality.  Tasks due between
    /// 9 PM and midnight Pacific leak into "tomorrow", and yesterday's stragglers
    /// linger in "today".  Syncing on every auth change + system TZ notification
    /// keeps the column fresh so server-side queries stay correct.
    ///
    /// **Tradeoff:** We accept a brief race window — the first `fetchToday` after
    /// a timezone change may still use the old value if it wins the race against
    /// this PATCH.  Layer 2 (the `timezone` query parameter on `fetchToday`) and
    /// Layer 3 (client-side re-bucketing) cover that gap.
    private var isSyncingTimezone = false

    private func syncTimezoneIfNeeded() async {
        guard auth.jwt != nil else { return }
        guard !isSyncingTimezone else { return }
        let deviceTZ = TimeZone.current.identifier
        guard auth.currentUser?.timezone != deviceTZ else { return }

        isSyncingTimezone = true
        defer { isSyncingTimezone = false }

        do {
            let _: UserResponse = try await auth.api.request(
                "PATCH", API.Users.profile,
                body: TimezoneUpdateRequest(timezone: deviceTZ)
            )
            auth.currentUser = auth.currentUser.map {
                UserDTO(
                    id: $0.id, email: $0.email, name: $0.name,
                    role: $0.role, timezone: deviceTZ, hasPassword: $0.hasPassword
                )
            }
            Logger.info("Synced timezone to \(deviceTZ)", category: .api)
        } catch {
            Logger.warning("Timezone sync failed: \(error)", category: .api)
        }
    }
}

private struct TimezoneUpdateRequest: Encodable {
    let timezone: String
}
