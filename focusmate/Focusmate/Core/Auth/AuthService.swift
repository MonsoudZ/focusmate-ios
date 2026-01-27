import Foundation

@MainActor
final class AuthService {
    private let api: APIClient
    private let authAPI: AuthAPI
    private let session: AuthSession

    init(api: APIClient, authAPI: AuthAPI, session: AuthSession) {
        self.api = api
        self.authAPI = authAPI
        self.session = session
    }

    func signIn(email: String, password: String) async throws -> (token: String, user: UserDTO) {
        let user = try await authAPI.signIn(email: email, password: password)
        let token = try await session.access()
        return (token, user)
    }

    func register(name: String, email: String, password: String) async throws -> (token: String, user: UserDTO) {
        let user = try await authAPI.signUp(name: name, email: email, password: password)
        let token = try await session.access()
        return (token, user)
    }

    func signInWithApple(identityToken: Data, name: String?) async throws -> (token: String, user: UserDTO) {
        guard let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw FocusmateError.custom("Sign In Failed", "Invalid Apple credentials")
        }

        let response: AuthSignInResponse = try await api.request(
            "POST",
            API.Auth.apple,
            body: AppleAuthRequest(idToken: tokenString, name: name)
        )

        return (response.token, response.user)
    }

    func forgotPassword(email: String) async throws {
        let _: EmptyResponse = try await api.request(
            "POST",
            API.Auth.password,
            body: ForgotPasswordRequest(email: email)
        )
    }
}
