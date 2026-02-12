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

        // When auth changes, attempt any deferred setup (like device registration)
        auth.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.objectWillChange.send()
                Task {
                    await self.tryRegisterDeviceIfPossible()
                    await self.tryAcceptPendingInvite()
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

        // Keep Sentry user context in sync with auth state.
        // Wired here (composition root) so AuthStore and SentryService stay decoupled.
        auth.$currentUser
            .receive(on: RunLoop.main)
            .sink { user in
                if let user {
                    SentryService.shared.setUser(id: user.id, email: user.email, name: user.name ?? "Unknown")
                } else {
                    SentryService.shared.clearUser()
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

    /// Accepts a pending invite code after the user signs in
    private func tryAcceptPendingInvite() async {
        guard auth.jwt != nil else { return }
        guard let code = pendingInviteCode else { return }

        pendingInviteCode = nil // Clear immediately to prevent duplicate attempts

        do {
            let response = try await inviteService.acceptInvite(code: code)
            joinedList = response.list
            Logger.info("Auto-accepted pending invite for list: \(response.list.name)", category: .api)
        } catch {
            Logger.warning("Failed to auto-accept pending invite: \(error)", category: .api)
            self.error = ErrorHandler.shared.handle(error, context: "Accept Invite")
        }
    }
}
