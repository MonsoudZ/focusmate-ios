import Foundation

@MainActor
@Observable
final class ListMembersViewModel {
    var memberships: [MembershipDTO] = []
    var friends: [FriendDTO] = []
    var isLoading = true
    var isLoadingFriends = false
    var error: FocusmateError?
    var showingInvite = false
    var memberToRemove: MembershipDTO?
    var addingFriendId: Int?
    var selectedRole: String = "editor"

    let list: ListDTO
    let apiClient: APIClient
    let inviteService: InviteService
    let friendService: FriendService

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
            self.error = ErrorHandler.shared.handle(error)
        }
        isLoading = false
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
            self.error = ErrorHandler.shared.handle(error)
        }
    }

    func loadFriends() async {
        isLoadingFriends = true
        do {
            friends = try await friendService.fetchFriends()
        } catch {
            // Silently fail - friends are optional
            Logger.warning("Failed to load friends: \(error)", category: .api)
        }
        isLoadingFriends = false
    }

    func addFriendToList(_ friend: FriendDTO) async {
        addingFriendId = friend.id
        do {
            let membership = try await friendService.addFriendToList(
                listId: list.id,
                friendId: friend.id,
                role: selectedRole
            )
            memberships.append(membership)
            HapticManager.success()
        } catch let err as FocusmateError {
            error = err
            HapticManager.error()
        } catch {
            self.error = ErrorHandler.shared.handle(error)
            HapticManager.error()
        }
        addingFriendId = nil
    }
}
