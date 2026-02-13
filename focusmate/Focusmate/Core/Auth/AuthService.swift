import Foundation

@MainActor
final class AuthService {
    private let api: APIClient
    private let authAPI: AuthAPI

    init(api: APIClient, authAPI: AuthAPI) {
        self.api = api
        self.authAPI = authAPI
    }

    func signIn(email: String, password: String) async throws -> (token: String, refreshToken: String?, user: UserDTO) {
        let res = try await authAPI.signIn(email: email, password: password)
        return (res.token, res.refreshToken, res.user)
    }

    func register(name: String, email: String, password: String) async throws -> (token: String, refreshToken: String?, user: UserDTO) {
        let res = try await authAPI.signUp(name: name, email: email, password: password)
        return (res.token, res.refreshToken, res.user)
    }

    func signInWithApple(identityToken: Data, name: String?) async throws -> (token: String, refreshToken: String?, user: UserDTO) {
        guard let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw FocusmateError.custom("Sign In Failed", "Invalid Apple credentials")
        }

        let response: AuthSignInResponse = try await api.request(
            "POST",
            API.Auth.apple,
            body: AppleAuthRequest(idToken: tokenString, name: name)
        )

        return (response.token, response.refreshToken, response.user)
    }

    func forgotPassword(email: String) async throws {
        let _: EmptyResponse = try await api.request(
            "POST",
            API.Auth.password,
            body: ForgotPasswordRequest(email: email)
        )
    }
}
