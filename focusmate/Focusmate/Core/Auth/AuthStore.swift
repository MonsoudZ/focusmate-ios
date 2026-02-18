import AuthenticationServices
import Combine
import Foundation

@MainActor
@Observable
final class AuthStore {
    var jwt: String? {
        didSet {
            Logger.debug("JWT updated: \(jwt != nil ? "SET" : "CLEARED")", category: .auth)
            eventBus.send(.tokenUpdated(hasToken: jwt != nil))
        }
    }

    var currentUser: UserDTO? {
        didSet {
            Logger.debug("Current user updated: \(Logger.sanitizeEmail(currentUser?.email ?? "nil"))", category: .auth)
            // Sync Sentry user context on every change.
            if let currentUser {
                SentryService.shared.setUser(id: currentUser.id, email: currentUser.email, name: currentUser.name ?? "Unknown")
            } else {
                SentryService.shared.clearUser()
            }
        }
    }

    var isLoading = false
    var isValidatingSession = false
    var error: FocusmateError?

    @ObservationIgnored private(set) lazy var api: APIClient = {
        if let injectedNetworking {
            return APIClient(
                tokenProvider: { [weak self] in self?.jwt },
                networking: injectedNetworking
            )
        }

        let kc = self.keychain
        return APIClient(
            tokenProvider: { [weak self] in self?.jwt },
            networking: InternalNetworking(
                tokenProvider: { [weak self] in self?.jwt },
                refreshTokenProvider: { kc.loadRefreshToken() },
                onTokenRefreshed: { [weak self] newToken, newRefreshToken in
                    await self?.handleTokenRefresh(newToken: newToken, newRefreshToken: newRefreshToken)
                }
            )
        )
    }()

    @ObservationIgnored private lazy var authAPI: AuthAPI = AuthAPI(api: api)
    @ObservationIgnored private lazy var authService: AuthService = AuthService(api: api, authAPI: authAPI)
    @ObservationIgnored private let errorHandler = ErrorHandler.shared

    @ObservationIgnored private let eventBus: AuthEventBus
    @ObservationIgnored private let keychain: KeychainManaging
    @ObservationIgnored private let injectedNetworking: NetworkingProtocol?
    @ObservationIgnored private let autoValidateOnInit: Bool
    @ObservationIgnored private let escalationService: EscalationService

    @ObservationIgnored private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored private var isHandlingUnauthorized = false
    @ObservationIgnored private var unauthorizedTask: Task<Void, Never>? {
        willSet { unauthorizedTask?.cancel() }
    }

    // MARK: - Production init (unchanged call site behavior)
    init() {
        self.eventBus = .shared
        self.keychain = KeychainManager.shared
        self.injectedNetworking = nil
        self.autoValidateOnInit = true
        self.escalationService = .shared

        bindAuthEvents()

        let loadedJWT = keychain.load()
        self.jwt = loadedJWT

        if autoValidateOnInit, loadedJWT != nil {
            Task { await validateSession() }
        }
    }

    // MARK: - DI init (tests / previews / dev tooling)
    init(
        keychain: KeychainManaging,
        networking: NetworkingProtocol?,
        autoValidateOnInit: Bool,
        eventBus: AuthEventBus? = nil,
        escalationService: EscalationService? = nil
    ) {
        self.eventBus = eventBus ?? .shared
        self.keychain = keychain
        self.injectedNetworking = networking
        self.autoValidateOnInit = autoValidateOnInit
        self.escalationService = escalationService ?? .shared

        bindAuthEvents()

        let loadedJWT = keychain.load()
        self.jwt = loadedJWT

        if autoValidateOnInit, loadedJWT != nil {
            Task { await validateSession() }
        }
    }

    private func bindAuthEvents() {
        eventBus.publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self else { return }
                if event == .unauthorized {
                    self.handleUnauthorizedEvent()
                }
            }
            .store(in: &cancellables)
    }

    func validateSession() async {
        guard jwt != nil else { return }

        isValidatingSession = true
        defer { isValidatingSession = false }

        do {
            let response: UserResponse = try await api.request(
                "GET",
                API.Users.profile,
                body: nil as String?
            )
            currentUser = response.user
            Logger.info("Session validated", category: .auth)
        } catch {
            Logger.warning("Session invalid, clearing: \(error)", category: .auth)
            clearLocalSession()
        }
    }

    func signIn(email: String, password: String) async {
        Logger.debug("Starting sign in for \(Logger.sanitizeEmail(email))", category: .auth)
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let result = try await authService.signIn(email: email, password: password)
            Logger.info("Sign in successful", category: .auth)
            setAuthenticatedSession(token: result.token, user: result.user, refreshToken: result.refreshToken)
            eventBus.send(.signedIn)
        } catch {
            Logger.error("Sign in failed", error: error, category: .auth)
            self.error = errorHandler.handle(error, context: "Sign In")
            if APIError.isCredentialError(error) {
                clearLocalSession()
            }
        }
    }

    func register(email: String, password: String, name: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let result = try await authService.register(name: name, email: email, password: password)
            Logger.info("Registration successful", category: .auth)
            setAuthenticatedSession(token: result.token, user: result.user, refreshToken: result.refreshToken)
            eventBus.send(.signedIn)
        } catch {
            Logger.error("Registration failed", error: error, category: .auth)
            self.error = errorHandler.handle(error, context: "Registration")
            if APIError.isCredentialError(error) {
                clearLocalSession()
            }
        }
    }

    func signOut() async {
        Logger.debug("Signing out", category: .auth)

        // Stop app blocking and escalation BEFORE clearing auth state.
        // If we clear auth first, the UI switches to SignInView and
        // the user has no way to remove the block.
        escalationService.resetAll()

        do {
            _ = try await api.request("DELETE", API.Auth.signOut, body: nil as String?) as EmptyResponse
            Logger.info("Sign out successful", category: .auth)
        } catch {
            Logger.warning("Remote sign out failed, continuing local sign out: \(error)", category: .auth)
        }

        clearLocalSession()
        eventBus.send(.signedOut)
    }

    // MARK: - Apple Sign In

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                Logger.error("Apple Sign In failed: Invalid credential type", category: .auth)
                self.error = FocusmateError.custom("Apple Sign In Failed", "Invalid credential type")
                return
            }

            guard let identityToken = appleIDCredential.identityToken else {
                Logger.error("Apple Sign In failed: No identity token", category: .auth)
                self.error = FocusmateError.custom("Apple Sign In Failed", "No identity token received from Apple")
                return
            }

            let name = [
                appleIDCredential.fullName?.givenName,
                appleIDCredential.fullName?.familyName
            ].compactMap { $0 }.joined(separator: " ")

            Task {
                await signInWithApple(
                    identityToken: identityToken,
                    name: name.isEmpty ? nil : name
                )
            }

        case .failure(let error):
            Logger.error("Apple Sign In failed", error: error, category: .auth)
            self.error = FocusmateError.custom("Apple Sign In Failed", error.localizedDescription)
        }
    }

    func signInWithApple(identityToken: Data, name: String?) async {
        Logger.debug("Starting Apple Sign In", category: .auth)
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let result = try await authService.signInWithApple(identityToken: identityToken, name: name)
            Logger.info("Apple Sign In successful", category: .auth)
            setAuthenticatedSession(token: result.token, user: result.user, refreshToken: result.refreshToken)
            eventBus.send(.signedIn)
        } catch {
            Logger.error("Apple Sign In failed", error: error, category: .auth)
            self.error = errorHandler.handle(error, context: "Apple Sign In")
            if APIError.isCredentialError(error) {
                clearLocalSession()
            }
        }
    }

    func forgotPassword(email: String) async {
        Logger.debug("Requesting password reset for \(Logger.sanitizeEmail(email))", category: .auth)
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            try await authService.forgotPassword(email: email)
            Logger.info("Password reset email sent", category: .auth)
        } catch {
            Logger.error("Password reset failed", error: error, category: .auth)
            self.error = errorHandler.handle(error, context: "Password Reset")
        }
    }

    private func handleUnauthorizedEvent() {
        // Atomic check-and-set to prevent race conditions.
        // Since AuthStore is @MainActor, synchronous flag access is thread-safe.
        guard jwt != nil else { return }
        guard !isHandlingUnauthorized else {
            Logger.debug("Already handling unauthorized event, skipping duplicate", category: .auth)
            return
        }

        isHandlingUnauthorized = true

        unauthorizedTask = Task {
            // defer ensures flag reset even if task is cancelled
            defer { isHandlingUnauthorized = false }

            Logger.warning("Global unauthorized received. Clearing local session.", category: .auth)
            escalationService.resetAll()
            _ = await errorHandler.handleUnauthorized()
            clearLocalSession()
            eventBus.send(.signedOut)
        }
    }

    private func setAuthenticatedSession(token: String, user: UserDTO, refreshToken: String? = nil) {
        jwt = token
        if !keychain.save(token: token) {
            Logger.error("Keychain token save failed — session will not survive app restart", category: .auth)
        }
        currentUser = user

        if let refreshToken {
            if !keychain.save(refreshToken: refreshToken) {
                Logger.error("Keychain refresh token save failed — silent re-auth will not work after restart", category: .auth)
            }
        }
    }

    /// Called by InternalNetworking after a successful token refresh.
    func handleTokenRefresh(newToken: String, newRefreshToken: String?) {
        jwt = newToken
        if !keychain.save(token: newToken) {
            Logger.error("Keychain token save failed during refresh — session will not survive app restart", category: .auth)
        }

        if let newRefreshToken {
            if !keychain.save(refreshToken: newRefreshToken) {
                Logger.error("Keychain refresh token save failed during refresh", category: .auth)
            }
        }
    }

    private func clearLocalSession() {
        jwt = nil
        currentUser = nil
        keychain.clear()
        keychain.clearRefreshToken()
        // Navigation state is cleared by AppRouter listening to AuthEventBus.signedOut
    }
}
