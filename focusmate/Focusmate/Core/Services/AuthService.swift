import Foundation

final class AuthService {
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - Authentication Endpoints
    
    func signIn(email: String, password: String) async throws -> SignInResponse {
        let request = SignInRequest(email: email, password: password)
        return try await apiClient.request("POST", "auth/sign_in", body: request)
    }
    
    func signUp(email: String, password: String, passwordConfirmation: String, name: String) async throws -> SignUpResponse {
        let request = SignUpRequest(
            email: email,
            password: password,
            passwordConfirmation: passwordConfirmation,
            name: name
        )
        return try await apiClient.request("POST", "auth/sign_up", body: request)
    }
    
    func signOut() async throws {
        _ = try await apiClient.request("DELETE", "auth/sign_out", body: nil as String?) as EmptyResponse
    }
    
    func refreshToken() async throws -> TokenRefreshResponse {
        return try await apiClient.request("POST", "auth/refresh", body: nil as String?)
    }
    
    // MARK: - Request/Response Models
    
    struct SignInRequest: Codable {
        let email: String
        let password: String
    }
    
    struct SignInResponse: Codable {
        let token: String
        let user: UserDTO
        
        enum CodingKeys: String, CodingKey {
            case token, user
        }
    }
    
    struct SignUpRequest: Codable {
        let email: String
        let password: String
        let passwordConfirmation: String
        let name: String
    }
    
    struct SignUpResponse: Codable {
        let token: String
        let user: UserDTO
        
        enum CodingKeys: String, CodingKey {
            case token, user
        }
    }
    
    struct TokenRefreshResponse: Codable {
        let token: String
        let expiresAt: Date
    }
    
    struct EmptyResponse: Codable {}
}
