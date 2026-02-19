import Foundation

@MainActor
@Observable
final class ChangePasswordViewModel {
  var currentPassword = ""
  var newPassword = ""
  var confirmPassword = ""
  var isLoading = false
  var error: FocusmateError?
  var showSuccess = false

  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  var isValid: Bool {
    !self.currentPassword.isEmpty &&
      self.newPassword.count >= 8 &&
      self.newPassword == self.confirmPassword
  }

  func changePassword() async {
    guard !self.isLoading else { return }
    self.isLoading = true
    self.error = nil
    defer { isLoading = false }

    do {
      let _: EmptyResponse = try await apiClient.request(
        "PATCH",
        API.Users.password,
        body: ChangePasswordRequest(
          currentPassword: self.currentPassword,
          password: self.newPassword,
          passwordConfirmation: self.confirmPassword
        )
      )
      HapticManager.success()
      self.showSuccess = true
    } catch let err as FocusmateError {
      error = err
      HapticManager.error()
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      HapticManager.error()
    }
  }
}
