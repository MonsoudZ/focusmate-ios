import Foundation

@MainActor
final class FriendService {
  let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  // MARK: - Input Validation

  private func validateRole(_ role: String) throws {
    let validRoles = ["owner", "editor", "viewer"]
    guard validRoles.contains(role) else {
      throw FocusmateError.validation(["role": ["must be one of: \(validRoles.joined(separator: ", "))"]], nil)
    }
  }

  // MARK: - Friend Operations

  func fetchFriends() async throws -> [FriendDTO] {
    let response: FriendsResponse = try await apiClient.request(
      "GET",
      API.Friends.list,
      body: nil as String?
    )
    return response.friends
  }

  func removeFriend(id: Int) async throws {
    try InputValidation.requirePositive(id, fieldName: "friend_id")
    let _: EmptyResponse = try await apiClient.request(
      "DELETE",
      API.Friends.friend(String(id)),
      body: nil as String?
    )
  }

  func addFriendToList(listId: Int, friendId: Int, role: String) async throws -> MembershipDTO {
    try InputValidation.requirePositive(listId, fieldName: "list_id")
    try InputValidation.requirePositive(friendId, fieldName: "friend_id")
    try self.validateRole(role)
    struct AddFriendRequest: Encodable {
      let membership: MembershipData

      struct MembershipData: Encodable {
        let user_id: Int
        let role: String
      }
    }

    let request = AddFriendRequest(
      membership: .init(user_id: friendId, role: role)
    )

    let response: MembershipResponse = try await apiClient.request(
      "POST",
      API.Lists.memberships(String(listId)),
      body: request
    )
    return response.membership
  }
}
