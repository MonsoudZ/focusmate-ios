import Foundation

@MainActor
@Observable
final class DeleteAccountViewModel {
  var password = ""
  var confirmText = ""
  var isLoading = false
  var error: FocusmateError?
  var showFinalConfirmation = false

  let requiredConfirmText = "DELETE"
  private let apiClient: APIClient
  private let authStore: AuthStore

  init(apiClient: APIClient, authStore: AuthStore) {
    self.apiClient = apiClient
    self.authStore = authStore
  }

  var isAppleUser: Bool {
    self.authStore.currentUser?.hasPassword == false
  }

  var canDelete: Bool {
    self.confirmText == self.requiredConfirmText &&
      (self.isAppleUser || !self.password.isEmpty)
  }

  func deleteAccount() async {
    guard !self.isLoading else { return }
    self.isLoading = true
    self.error = nil
    defer { isLoading = false }

    do {
      let _: EmptyResponse = try await apiClient.request(
        "DELETE",
        API.Users.profile,
        body: DeleteAccountRequest(password: self.isAppleUser ? nil : self.password)
      )

      await self.authStore.signOut()
    } catch let err as FocusmateError {
      error = err
      HapticManager.error()
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      HapticManager.error()
    }
  }
}
