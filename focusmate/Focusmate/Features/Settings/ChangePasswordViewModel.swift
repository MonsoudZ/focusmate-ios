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
        !currentPassword.isEmpty &&
        newPassword.count >= 8 &&
        newPassword == confirmPassword
    }

    func changePassword() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let _: EmptyResponse = try await apiClient.request(
                "PATCH",
                API.Users.password,
                body: ChangePasswordRequest(
                    currentPassword: currentPassword,
                    password: newPassword,
                    passwordConfirmation: confirmPassword
                )
            )
            HapticManager.success()
            showSuccess = true
        } catch let err as FocusmateError {
            error = err
            HapticManager.error()
        } catch {
            self.error = ErrorHandler.shared.handle(error)
            HapticManager.error()
        }
    }
}
