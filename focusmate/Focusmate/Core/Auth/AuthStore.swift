import Combine
import Foundation
import AuthenticationServices

@MainActor
final class AuthStore: ObservableObject {
    @Published var jwt: String? {
        didSet {
            Logger.debug("JWT updated: \(jwt != nil ? "SET" : "CLEARED")", category: .auth)
            AuthEventBus.shared.send(.tokenUpdated(hasToken: jwt != nil))
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

    private(set) lazy var api: APIClient = APIClient(
        tokenProvider: { [weak self] in self?.jwt },
        networking: injectedNetworking ?? InternalNetworking(tokenProvider: { [weak self] in self?.jwt })
    )

    private let authSession = AuthSession()
    private lazy var authAPI: AuthAPI = AuthAPI(api: api, session: authSession)
    private let errorHandler = ErrorHandler.shared

    private let keychain: KeychainManaging
    private let injectedNetworking: NetworkingProtocol?
    private let autoValidateOnInit: Bool

    private var cancellables = Set<AnyCancellable>()
    private var unauthorizedTask: Task<Void, Never>?

    // MARK: - Production init (unchanged call site behavior)
    init() {
        self.keychain = KeychainManager.shared
        self.injectedNetworking = nil
        self.autoValidateOnInit = true

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
        autoValidateOnInit: Bool
    ) {
        self.keychain = keychain
        self.injectedNetworking = networking
        self.autoValidateOnInit = autoValidateOnInit

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
        AuthEventBus.shared.publisher
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
            let user: UserDTO = try await api.request(
                "GET",
                API.Users.profile,
                body: nil as String?
            )
            currentUser = user
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
            let user = try await authAPI.signIn(email: email, password: password)
            Logger.info("Sign in successful", category: .auth)

            let token = try await authSession.access()
            await setAuthenticatedSession(token: token, user: user)

            AuthEventBus.shared.send(.signedIn)
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
            let user = try await authAPI.signUp(name: name, email: email, password: password)
            Logger.info("Registration successful", category: .auth)

            let token = try await authSession.access()
            await setAuthenticatedSession(token: token, user: user)

            AuthEventBus.shared.send(.signedIn)
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
        EscalationService.shared.resetAll()

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

        AuthEventBus.shared.send(.signedOut)
    }


    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
               let identityToken = appleIDCredential.identityToken {

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

        guard let tokenString = String(data: identityToken, encoding: .utf8) else {
            Logger.error("Failed to convert Apple identity token to string", category: .auth)
            self.error = FocusmateError.custom("Sign In Failed", "Invalid Apple credentials")
            return
        }

        do {
            let response: AuthSignInResponse = try await api.request(
                "POST",
                "api/v1/auth/apple",
                body: AppleAuthRequest(idToken: tokenString, name: name)
            )

            Logger.info("Apple Sign In successful", category: .auth)
            await setAuthenticatedSession(token: response.token, user: response.user)

            AuthEventBus.shared.send(.signedIn)
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
            let _: EmptyResponse = try await api.request(
                "POST",
                "api/v1/auth/password",
                body: ForgotPasswordRequest(email: email)
            )
            Logger.info("Password reset email sent", category: .auth)
        } catch {
            Logger.error("Password reset failed", error: error, category: .auth)
            self.error = errorHandler.handle(error, context: "Password Reset")
        }
    }

    private func handleUnauthorizedEvent() {
        // Cancel any in-flight handling and ignore if already signed out.
        guard jwt != nil else { return }
        unauthorizedTask?.cancel()

        unauthorizedTask = Task {
            Logger.warning("Global unauthorized received. Clearing local session.", category: .auth)

            // Stop app blocking before clearing auth to prevent stuck blocks
            EscalationService.shared.resetAll()

            _ = await errorHandler.handleUnauthorized()
            await clearLocalSession()

            AuthEventBus.shared.send(.signedOut)
        }
    }

    private func setAuthenticatedSession(token: String, user: UserDTO) async {
        await authSession.set(token: token)
        jwt = token
        keychain.save(token: token)
        currentUser = user
    }

    private func clearLocalSession() async {
        await authSession.clear()
        jwt = nil
        currentUser = nil
        keychain.clear()
    }
}
