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
    !self.email.trimmingCharacters(in: .whitespaces).isEmpty &&
      self.email.contains("@")
  }

  func invite() async -> Bool {
    self.isLoading = true
    self.error = nil
    defer { isLoading = false }

    do {
      let _: MembershipResponse = try await apiClient.request(
        "POST",
        API.Lists.memberships(String(self.list.id)),
        body: CreateMembershipRequest(
          membership: MembershipParams(
            user_identifier: self.email.trimmingCharacters(in: .whitespaces).lowercased(),
            role: self.role
          )
        )
      )
      return true
    } catch let err as FocusmateError {
      error = err
      HapticManager.error()
    } catch {
      self.error = ErrorHandler.shared.handle(error, context: "Inviting member")
      HapticManager.error()
    }

    return false
  }
}
