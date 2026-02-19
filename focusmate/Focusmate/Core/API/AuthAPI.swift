import Foundation

final class AuthAPI {
  private let api: APIClient

  init(api: APIClient) {
    self.api = api
  }

  func signIn(email: String, password: String) async throws -> AuthSignInResponse {
    try await self.api.request(
      "POST", API.Auth.signIn,
      body: AuthSignInBody(user: .init(email: email, password: password))
    )
  }

  func signUp(name: String, email: String, password: String) async throws -> AuthSignInResponse {
    let timezone = TimeZone.current.identifier

    return try await self.api.request(
      "POST", API.Auth.signUp,
      body: AuthSignUpBody(user: .init(
        email: email,
        password: password,
        password_confirmation: password,
        name: name,
        timezone: timezone
      ))
    )
  }
}
