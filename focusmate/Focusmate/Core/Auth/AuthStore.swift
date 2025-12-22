import Combine
import Foundation
import AuthenticationServices

@MainActor
final class AuthStore: ObservableObject {
    @Published var jwt: String? {
        didSet {
            Logger.debug("JWT updated: \(jwt != nil ? "SET" : "CLEARED")", category: .auth)
        }
    }

    @Published var currentUser: UserDTO? {
        didSet {
            Logger.debug("Current user updated: \(Logger.sanitizeEmail(currentUser?.email ?? "nil"))", category: .auth)
        }
    }

    @Published var isLoading = false
    @Published var error: FocusmateError?

    private(set) lazy var api: APIClient = APIClient { [weak self] in self?.jwt }
    private let authSession = AuthSession()
    private lazy var authAPI: AuthAPI = AuthAPI(api: api, session: authSession)
    private let errorHandler = ErrorHandler.shared

    init() {
        let loadedJWT = KeychainManager.shared.load()
        self.jwt = loadedJWT

        if let token = loadedJWT {
            Task {
                await authSession.set(token: token)
            }
        }
    }

    func signIn(email: String, password: String) async {
        Logger.debug("Starting sign in for \(Logger.sanitizeEmail(email))", category: .auth)
        isLoading = true
        error = nil

        do {
            let user = try await authAPI.signIn(email: email, password: password)
            Logger.info("Sign in successful", category: .auth)

            let token = try await authSession.access()

            jwt = token
            KeychainManager.shared.save(token: token)
            currentUser = user
        } catch {
            Logger.error("Sign in failed", error: error, category: .auth)
            self.error = errorHandler.handle(error, context: "Sign In")
            jwt = nil
            KeychainManager.shared.clear()
        }

        isLoading = false
    }

    func register(email: String, password: String, name: String) async {
        isLoading = true
        error = nil

        do {
            let user = try await authAPI.signUp(name: name, email: email, password: password)
            Logger.info("Registration successful", category: .auth)

            let token = try await authSession.access()

            jwt = token
            KeychainManager.shared.save(token: token)
            currentUser = user
        } catch {
            Logger.error("Registration failed", error: error, category: .auth)
            self.error = errorHandler.handle(error, context: "Registration")
            jwt = nil
            KeychainManager.shared.clear()
        }

        isLoading = false
    }

    func signOut() async {
        Logger.debug("Signing out", category: .auth)
        _ = try? await api.request("DELETE", API.Auth.signOut, body: nil as String?) as EmptyResponse
        Logger.info("Sign out successful", category: .auth)

        await authSession.clear()

        jwt = nil
        currentUser = nil
        KeychainManager.shared.clear()
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

        guard let tokenString = String(data: identityToken, encoding: .utf8) else {
            Logger.error("Failed to convert Apple identity token to string", category: .auth)
            self.error = FocusmateError.custom("Sign In Failed", "Invalid Apple credentials")
            isLoading = false
            return
        }

        do {
            let response: AuthSignInResponse = try await api.request(
                "POST",
                "api/v1/auth/apple",
                body: AppleAuthRequest(idToken: tokenString, name: name)
            )

            Logger.info("Apple Sign In successful", category: .auth)

            jwt = response.token
            KeychainManager.shared.save(token: response.token)
            currentUser = response.user
        } catch {
            Logger.error("Apple Sign In failed", error: error, category: .auth)
            self.error = errorHandler.handle(error, context: "Apple Sign In")
            jwt = nil
            KeychainManager.shared.clear()
        }

        isLoading = false
    }
}
