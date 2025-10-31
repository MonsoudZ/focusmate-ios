import Foundation

final class AuthAPI {
    private let api: NewAPIClient
    private let session: AuthSession
    init(api: NewAPIClient, session: AuthSession) { 
        self.api = api
        self.session = session 
    }

    func signIn(email: String, password: String) async throws -> UserDTO {
        // Mock mode for testing
        if API.isMockMode {
            print("🧪 Mock mode: Simulating successful sign in")
            let mockUser = UserDTO(id: 1, email: email, name: "Test User", role: "client", timezone: "UTC")
            await session.set(token: "mock-jwt-token")
            return mockUser
        }
        
        let res: AuthSignInResponse = try await api.request(
            "POST", API.Auth.signIn,
            body: AuthSignInBody(authentication: .init(email: email, password: password)),
            authRequired: false
        )
        await session.set(token: res.token)
        return res.user
    }

    func signUp(name: String, email: String, password: String) async throws -> UserDTO {
        // Mock mode for testing
        if API.isMockMode {
            print("🧪 Mock mode: Simulating successful sign up")
            let mockUser = UserDTO(id: 1, email: email, name: name, role: "client", timezone: "UTC")
            await session.set(token: "mock-jwt-token")
            return mockUser
        }
        
        let res: AuthSignInResponse = try await api.request(
            "POST", API.Auth.signUp,
            body: AuthSignUpBody(authentication: .init(email: email, password: password,
                                                       password_confirmation: password, name: name)),
            authRequired: false
        )
        await session.set(token: res.token)
        return res.user
    }

    func signOut() async {
        _ = try? await api.request("DELETE", API.Auth.signOut) as Empty
        await session.clear()
    }
}
