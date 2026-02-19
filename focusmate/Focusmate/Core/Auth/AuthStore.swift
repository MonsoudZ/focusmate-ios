import AuthenticationServices
import Combine
import Foundation

@MainActor
@Observable
final class AuthStore {
  var jwt: String? {
    didSet {
      Logger.debug("JWT updated: \(self.jwt != nil ? "SET" : "CLEARED")", category: .auth)
      self.eventBus.send(.tokenUpdated(hasToken: self.jwt != nil))
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

  @ObservationIgnored private lazy var authAPI: AuthAPI = .init(api: api)
  @ObservationIgnored private lazy var authService: AuthService = .init(api: api, authAPI: authAPI)
  @ObservationIgnored private let errorHandler = ErrorHandler.shared

  @ObservationIgnored private let eventBus: AuthEventBus
  @ObservationIgnored private let keychain: KeychainManaging
  @ObservationIgnored private let injectedNetworking: NetworkingProtocol?
  @ObservationIgnored private let autoValidateOnInit: Bool
  @ObservationIgnored private let escalationService: EscalationService

  @ObservationIgnored private var cancellables = Set<AnyCancellable>()
  @ObservationIgnored private var isHandlingUnauthorized = false
  @ObservationIgnored private var unauthorizedTask: Task<Void, Never>? {
    willSet { self.unauthorizedTask?.cancel() }
  }

  // MARK: - Production init (unchanged call site behavior)

  init() {
    self.eventBus = .shared
    self.keychain = KeychainManager.shared
    self.injectedNetworking = nil
    self.autoValidateOnInit = true
    self.escalationService = .shared

    self.bindAuthEvents()

    let loadedJWT = self.keychain.load()
    self.jwt = loadedJWT

    if self.autoValidateOnInit, loadedJWT != nil {
      Task { await self.validateSession() }
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

    self.bindAuthEvents()

    let loadedJWT = keychain.load()
    self.jwt = loadedJWT

    if autoValidateOnInit, loadedJWT != nil {
      Task { await self.validateSession() }
    }
  }

  private func bindAuthEvents() {
    self.eventBus.publisher
      .receive(on: RunLoop.main)
      .sink { [weak self] event in
        guard let self else { return }
        if event == .unauthorized {
          self.handleUnauthorizedEvent()
        }
      }
      .store(in: &self.cancellables)
  }

  func validateSession() async {
    guard self.jwt != nil else { return }

    self.isValidatingSession = true
    defer { isValidatingSession = false }

    do {
      let response: UserResponse = try await api.request(
        "GET",
        API.Users.profile,
        body: nil as String?
      )
      self.currentUser = response.user
      Logger.info("Session validated", category: .auth)
    } catch {
      Logger.warning("Session invalid, clearing: \(error)", category: .auth)
      self.clearLocalSession()
    }
  }

  func signIn(email: String, password: String) async {
    Logger.debug("Starting sign in for \(Logger.sanitizeEmail(email))", category: .auth)
    self.isLoading = true
    self.error = nil
    defer { isLoading = false }

    do {
      let result = try await authService.signIn(email: email, password: password)
      Logger.info("Sign in successful", category: .auth)
      self.setAuthenticatedSession(token: result.token, user: result.user, refreshToken: result.refreshToken)
      self.eventBus.send(.signedIn)
    } catch {
      Logger.error("Sign in failed", error: error, category: .auth)
      self.error = self.errorHandler.handle(error, context: "Sign In")
      if APIError.isCredentialError(error) {
        self.clearLocalSession()
      }
    }
  }

  func register(email: String, password: String, name: String) async {
    self.isLoading = true
    self.error = nil
    defer { isLoading = false }

    do {
      let result = try await authService.register(name: name, email: email, password: password)
      Logger.info("Registration successful", category: .auth)
      self.setAuthenticatedSession(token: result.token, user: result.user, refreshToken: result.refreshToken)
      self.eventBus.send(.signedIn)
    } catch {
      Logger.error("Registration failed", error: error, category: .auth)
      self.error = self.errorHandler.handle(error, context: "Registration")
      if APIError.isCredentialError(error) {
        self.clearLocalSession()
      }
    }
  }

  func signOut() async {
    Logger.debug("Signing out", category: .auth)

    // Stop app blocking and escalation BEFORE clearing auth state.
    // If we clear auth first, the UI switches to SignInView and
    // the user has no way to remove the block.
    self.escalationService.resetAll()

    do {
      _ = try await self.api.request("DELETE", API.Auth.signOut, body: nil as String?) as EmptyResponse
      Logger.info("Sign out successful", category: .auth)
    } catch {
      Logger.warning("Remote sign out failed, continuing local sign out: \(error)", category: .auth)
    }

    self.clearLocalSession()
    self.eventBus.send(.signedOut)
  }

  // MARK: - Apple Sign In

  func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
    switch result {
    case let .success(authorization):
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
        appleIDCredential.fullName?.familyName,
      ].compactMap { $0 }.joined(separator: " ")

      Task {
        await self.signInWithApple(
          identityToken: identityToken,
          name: name.isEmpty ? nil : name
        )
      }

    case let .failure(error):
      Logger.error("Apple Sign In failed", error: error, category: .auth)
      self.error = FocusmateError.custom("Apple Sign In Failed", error.localizedDescription)
    }
  }

  func signInWithApple(identityToken: Data, name: String?) async {
    Logger.debug("Starting Apple Sign In", category: .auth)
    self.isLoading = true
    self.error = nil
    defer { isLoading = false }

    do {
      let result = try await authService.signInWithApple(identityToken: identityToken, name: name)
      Logger.info("Apple Sign In successful", category: .auth)
      self.setAuthenticatedSession(token: result.token, user: result.user, refreshToken: result.refreshToken)
      self.eventBus.send(.signedIn)
    } catch {
      Logger.error("Apple Sign In failed", error: error, category: .auth)
      self.error = self.errorHandler.handle(error, context: "Apple Sign In")
      if APIError.isCredentialError(error) {
        self.clearLocalSession()
      }
    }
  }

  func forgotPassword(email: String) async {
    Logger.debug("Requesting password reset for \(Logger.sanitizeEmail(email))", category: .auth)
    self.isLoading = true
    self.error = nil
    defer { isLoading = false }

    do {
      try await self.authService.forgotPassword(email: email)
      Logger.info("Password reset email sent", category: .auth)
    } catch {
      Logger.error("Password reset failed", error: error, category: .auth)
      self.error = self.errorHandler.handle(error, context: "Password Reset")
    }
  }

  private func handleUnauthorizedEvent() {
    // Atomic check-and-set to prevent race conditions.
    // Since AuthStore is @MainActor, synchronous flag access is thread-safe.
    guard self.jwt != nil else { return }
    guard !self.isHandlingUnauthorized else {
      Logger.debug("Already handling unauthorized event, skipping duplicate", category: .auth)
      return
    }

    self.isHandlingUnauthorized = true

    self.unauthorizedTask = Task {
      // defer ensures flag reset even if task is cancelled
      defer { isHandlingUnauthorized = false }

      Logger.warning("Global unauthorized received. Clearing local session.", category: .auth)
      self.escalationService.resetAll()
      _ = await self.errorHandler.handleUnauthorized()
      self.clearLocalSession()
      self.eventBus.send(.signedOut)
    }
  }

  private func setAuthenticatedSession(token: String, user: UserDTO, refreshToken: String? = nil) {
    self.jwt = token
    if !self.keychain.save(token: token) {
      Logger.error("Keychain token save failed — session will not survive app restart", category: .auth)
    }
    self.currentUser = user

    if let refreshToken {
      if !self.keychain.save(refreshToken: refreshToken) {
        Logger.error("Keychain refresh token save failed — silent re-auth will not work after restart", category: .auth)
      }
    }
  }

  /// Called by InternalNetworking after a successful token refresh.
  func handleTokenRefresh(newToken: String, newRefreshToken: String?) {
    self.jwt = newToken
    if !self.keychain.save(token: newToken) {
      Logger.error("Keychain token save failed during refresh — session will not survive app restart", category: .auth)
    }

    if let newRefreshToken {
      if !self.keychain.save(refreshToken: newRefreshToken) {
        Logger.error("Keychain refresh token save failed during refresh", category: .auth)
      }
    }
  }

  private func clearLocalSession() {
    self.jwt = nil
    self.currentUser = nil
    self.keychain.clear()
    self.keychain.clearRefreshToken()
    // Navigation state is cleared by AppRouter listening to AuthEventBus.signedOut
  }
}
