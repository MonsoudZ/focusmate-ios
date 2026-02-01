import Foundation

final class FriendService: Sendable {
    let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Input Validation

    private func validateId(_ id: Int, name: String) throws {
        guard id > 0 else {
            throw FocusmateError.validation([name: ["must be a positive number"]], nil)
        }
    }

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
        try validateId(id, name: "friend_id")
        let _: EmptyResponse = try await apiClient.request(
            "DELETE",
            API.Friends.friend(String(id)),
            body: nil as String?
        )
    }

    func addFriendToList(listId: Int, friendId: Int, role: String) async throws -> MembershipDTO {
        try validateId(listId, name: "list_id")
        try validateId(friendId, name: "friend_id")
        try validateRole(role)
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

