import Foundation

@MainActor
@Observable
final class EditProfileViewModel {
    var name: String
    var timezone: String
    var isLoading = false
    var error: FocusmateError?

    private let apiClient: APIClient

    init(user: UserDTO, apiClient: APIClient) {
        self.name = user.name ?? ""
        self.timezone = user.timezone ?? TimeZone.current.identifier
        self.apiClient = apiClient
    }

    func updateProfile() async -> UserDTO? {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response: UserResponse = try await apiClient.request(
                "PATCH",
                API.Users.profile,
                body: UpdateProfileRequest(name: name, timezone: timezone)
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
