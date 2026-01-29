import Combine
import Foundation
import AuthenticationServices

@MainActor
final class AuthStore: ObservableObject {
    @Published var jwt: String? {
        didSet {
            Logger.debug("JWT updated: \(jwt != nil ? "SET" : "CLEARED")", category: .auth)
            eventBus.send(.tokenUpdated(hasToken: jwt != nil))
        }
    }

    @Published var currentUser: UserDTO? {
        didSet {
            Logger.debug("Current user updated: \(Logger.sanitizeEmail(currentUser?.email ?? "nil"))", category: .auth)
        }
    }

    @Published var isLoading = false
    @Published var isValidatingSession = false
    @Published var error: FocusmateError?

    private(set) lazy var api: APIClient = {
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

    private let authSession = AuthSession()
    private lazy var authAPI: AuthAPI = AuthAPI(api: api, session: authSession)
    private lazy var authService: AuthService = AuthService(api: api, authAPI: authAPI, session: authSession)
    private let errorHandler = ErrorHandler.shared

    private let eventBus: AuthEventBus
    private let keychain: KeychainManaging
    private let injectedNetworking: NetworkingProtocol?
    private let autoValidateOnInit: Bool
    private let escalationService: EscalationService

    private var cancellables = Set<AnyCancellable>()
    private var unauthorizedTask: Task<Void, Never>? {
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

        if autoValidateOnInit, let token = loadedJWT {
            Task {
                await authSession.set(token: token)
                await validateSession()
            }
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

        if autoValidateOnInit, let token = loadedJWT {
            Task {
                await authSession.set(token: token)
                await validateSession()
            }
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
            await clearLocalSession()
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
            await setAuthenticatedSession(token: result.token, user: result.user, refreshToken: result.refreshToken)
            eventBus.send(.signedIn)
        } catch {
            Logger.error("Sign in failed", error: error, category: .auth)
            self.error = errorHandler.handle(error, context: "Sign In")
            await clearLocalSession()
        }
    }

    func register(email: String, password: String, name: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let result = try await authService.register(name: name, email: email, password: password)
            Logger.info("Registration successful", category: .auth)
            await setAuthenticatedSession(token: result.token, user: result.user, refreshToken: result.refreshToken)
            eventBus.send(.signedIn)
        } catch {
            Logger.error("Registration failed", error: error, category: .auth)
            self.error = errorHandler.handle(error, context: "Registration")
            await clearLocalSession()
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

        await clearLocalSession()
        await ResponseCache.shared.invalidateAll()

        // Reset one-time authenticated boot state
        AppSettings.shared.didCompleteAuthenticatedBoot = false
        AppSettings.shared.hasCompletedOnboarding = false

        eventBus.send(.signedOut)
    }


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
            await setAuthenticatedSession(token: result.token, user: result.user, refreshToken: result.refreshToken)
            eventBus.send(.signedIn)
        } catch {
            Logger.error("Apple Sign In failed", error: error, category: .auth)
            self.error = errorHandler.handle(error, context: "Apple Sign In")
            await clearLocalSession()
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
        guard jwt != nil else { return }

        unauthorizedTask = Task {
            Logger.warning("Global unauthorized received. Clearing local session.", category: .auth)
            escalationService.resetAll()
            _ = await errorHandler.handleUnauthorized()
            await clearLocalSession()
            eventBus.send(.signedOut)
        }
    }

    private func setAuthenticatedSession(token: String, user: UserDTO, refreshToken: String? = nil) async {
        await authSession.set(token: token)
        jwt = token
        keychain.save(token: token)
        currentUser = user

        if let refreshToken {
            await authSession.setRefreshToken(refreshToken)
            keychain.save(refreshToken: refreshToken)
        }
    }

    /// Called by InternalNetworking after a successful token refresh.
    func handleTokenRefresh(newToken: String, newRefreshToken: String?) async {
        await authSession.set(token: newToken)
        jwt = newToken
        keychain.save(token: newToken)

        if let newRefreshToken {
            await authSession.setRefreshToken(newRefreshToken)
            keychain.save(refreshToken: newRefreshToken)
        }
    }

    private func clearLocalSession() async {
        await authSession.clear()
        jwt = nil
        currentUser = nil
        keychain.clear()
        keychain.clearRefreshToken()
    }
}
