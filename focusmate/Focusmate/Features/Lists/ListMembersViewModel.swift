import Foundation

@MainActor
@Observable
final class ListMembersViewModel {
    var memberships: [MembershipDTO] = []
    var friends: [FriendDTO] = []
    var isLoading = true
    var isLoadingFriends = false
    var error: FocusmateError?
    var memberToRemove: MembershipDTO?
    var addingFriendId: Int?
    var selectedRole: String = "editor"

    let list: ListDTO
    let apiClient: APIClient
    let inviteService: InviteService
    let friendService: FriendService

    var isOwner: Bool {
        list.role == "owner"
    }

    init(list: ListDTO, apiClient: APIClient, inviteService: InviteService, friendService: FriendService) {
        self.list = list
        self.apiClient = apiClient
        self.inviteService = inviteService
        self.friendService = friendService
    }

    /// Friends who are not already members of this list
    var availableFriends: [FriendDTO] {
        let memberUserIds = Set(memberships.compactMap { $0.user.id })
        return friends.filter { !memberUserIds.contains($0.id) }
    }

    func loadMembers() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response: MembershipsResponse = try await apiClient.request(
                "GET",
                API.Lists.memberships(String(list.id)),
                body: nil as String?
            )
            memberships = response.memberships
        } catch let err as FocusmateError {
            error = err
        } catch {
            self.error = ErrorHandler.shared.handle(error, context: "Loading members")
        }
    }

    func removeMember(_ membership: MembershipDTO) async {
        do {
            let _: EmptyResponse = try await apiClient.request(
                "DELETE",
                API.Lists.membership(String(list.id), String(membership.id)),
                body: nil as String?
            )
            memberships.removeAll { $0.id == membership.id }
            memberToRemove = nil
        } catch let err as FocusmateError {
            error = err
        } catch {
            self.error = ErrorHandler.shared.handle(error, context: "Removing member")
        }
    }

    func loadFriends() async {
        isLoadingFriends = true
        defer { isLoadingFriends = false }

        do {
            friends = try await friendService.fetchFriends()
        } catch {
            // Silently fail - friends are optional enhancement
            Logger.warning("Failed to load friends: \(error)", category: .api)
        }
    }

    func updateMemberRole(_ membership: MembershipDTO, newRole: String) async {
        let originalMemberships = memberships

        // Optimistic update
        if let idx = memberships.firstIndex(where: { $0.id == membership.id }) {
            let updated = MembershipDTO(
                id: membership.id,
                user: membership.user,
                role: newRole,
                created_at: membership.created_at,
                updated_at: membership.updated_at
            )
            memberships[idx] = updated
        }

        do {
            let response: MembershipResponse = try await apiClient.request(
                "PATCH",
                API.Lists.membership(String(list.id), String(membership.id)),
                body: UpdateMembershipRequest(membership: UpdateMembershipParams(role: newRole))
            )
            if let idx = memberships.firstIndex(where: { $0.id == response.membership.id }) {
                memberships[idx] = response.membership
            }
            HapticManager.success()
        } catch {
            memberships = originalMemberships
            self.error = ErrorHandler.shared.handle(error, context: "Updating member role")
            HapticManager.error()
        }
    }

    func addFriendToList(_ friend: FriendDTO) async {
        addingFriendId = friend.id
        defer { addingFriendId = nil }

        do {
            let membership = try await friendService.addFriendToList(
                listId: list.id,
                friendId: friend.id,
                role: selectedRole
            )
            memberships.append(membership)
            HapticManager.success()
        } catch let err as FocusmateError {
            Logger.error("Failed to add friend to list", error: err, category: .api)
            error = err
            HapticManager.error()
        } catch {
            Logger.error("Failed to add friend to list", error: error, category: .api)
            self.error = ErrorHandler.shared.handle(error, context: "Adding friend to list")
            HapticManager.error()
        }
    }
}
