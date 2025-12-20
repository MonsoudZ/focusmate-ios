import Foundation

final class AuthAPI {
    private let api: APIClient
    private let session: AuthSession

    init(api: APIClient, session: AuthSession) {
        self.api = api
        self.session = session
    }

    func signIn(email: String, password: String) async throws -> UserDTO {
        let res: AuthSignInResponse = try await api.request(
            "POST", API.Auth.signIn,
            body: AuthSignInBody(user: .init(email: email, password: password))
        )
        await session.set(token: res.token)
        return res.user
    }

    func signUp(name: String, email: String, password: String) async throws -> UserDTO {
        let timezone = TimeZone.current.identifier

        let res: AuthSignInResponse = try await api.request(
            "POST", API.Auth.signUp,
            body: AuthSignUpBody(user: .init(
                email: email,
                password: password,
                password_confirmation: password,
                name: name,
                timezone: timezone
            ))
        )
        await session.set(token: res.token)
        return res.user
    }

    func signOut() async {
        _ = try? await api.request("DELETE", API.Auth.signOut, body: nil as String?) as EmptyResponse
        await session.clear()
    }
}
