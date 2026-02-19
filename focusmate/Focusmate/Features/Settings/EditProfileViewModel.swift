import Foundation

@MainActor
@Observable
final class EditProfileViewModel {
  var name: String
  var isLoading = false
  var error: FocusmateError?

  private let apiClient: APIClient

  init(user: UserDTO, apiClient: APIClient) {
    self.name = user.name ?? ""
    self.apiClient = apiClient
  }

  func updateProfile() async -> UserDTO? {
    self.isLoading = true
    self.error = nil
    defer { isLoading = false }

    do {
      let response: UserResponse = try await apiClient.request(
        "PATCH",
        API.Users.profile,
        body: UpdateProfileRequest(name: self.name, timezone: TimeZone.current.identifier)
      )
      HapticManager.success()
      return response.user
    } catch let err as FocusmateError {
      error = err
      HapticManager.error()
    } catch {
      self.error = ErrorHandler.shared.handle(error, context: "Updating profile")
      HapticManager.error()
    }

    return nil
  }
}
