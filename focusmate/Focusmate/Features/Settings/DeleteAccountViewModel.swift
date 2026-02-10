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
        authStore.currentUser?.hasPassword == false
    }

    var canDelete: Bool {
        confirmText == requiredConfirmText &&
        (isAppleUser || !password.isEmpty)
    }

    func deleteAccount() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let _: EmptyResponse = try await apiClient.request(
                "DELETE",
                API.Users.profile,
                body: DeleteAccountRequest(password: isAppleUser ? nil : password)
            )

            await authStore.signOut()
        } catch let err as FocusmateError {
            error = err
            HapticManager.error()
        } catch {
            self.error = ErrorHandler.shared.handle(error)
            HapticManager.error()
        }

        isLoading = false
    }
}
