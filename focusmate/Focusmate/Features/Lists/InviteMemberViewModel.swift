import Foundation

@MainActor
@Observable
final class InviteMemberViewModel {
    var email = ""
    var role = "editor"
    var isLoading = false
    var error: FocusmateError?

    private let list: ListDTO
    private let apiClient: APIClient

    init(list: ListDTO, apiClient: APIClient) {
        self.list = list
        self.apiClient = apiClient
    }

    var isValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        email.contains("@")
    }

    func invite() async -> Bool {
        isLoading = true
        error = nil

        do {
            let _: MembershipResponse = try await apiClient.request(
                "POST",
                API.Lists.memberships(String(list.id)),
                body: CreateMembershipRequest(
                    membership: MembershipParams(
                        user_identifier: email.trimmingCharacters(in: .whitespaces).lowercased(),
                        role: role
                    )
                )
            )
            isLoading = false
            return true
        } catch let err as FocusmateError {
            error = err
        } catch {
            self.error = ErrorHandler.shared.handle(error)
        }

        isLoading = false
        return false
    }
}
