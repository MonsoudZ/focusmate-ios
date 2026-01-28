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
        newPassword.count >= 6 &&
        newPassword == confirmPassword
    }

    func changePassword() async {
        isLoading = true
        error = nil

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
            showSuccess = true
        } catch let err as FocusmateError {
            error = err
        } catch {
            self.error = ErrorHandler.shared.handle(error)
        }

        isLoading = false
    }
}
