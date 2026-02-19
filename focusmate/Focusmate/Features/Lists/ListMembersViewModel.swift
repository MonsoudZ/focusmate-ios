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
    self.list.role == "owner"
  }

  init(list: ListDTO, apiClient: APIClient, inviteService: InviteService, friendService: FriendService) {
    self.list = list
    self.apiClient = apiClient
    self.inviteService = inviteService
    self.friendService = friendService
  }

  /// Friends who are not already members of this list
  var availableFriends: [FriendDTO] {
    let memberUserIds = Set(memberships.compactMap(\.user.id))
    return self.friends.filter { !memberUserIds.contains($0.id) }
  }

  func loadMembers() async {
    self.isLoading = true
    defer { isLoading = false }

    do {
      let response: MembershipsResponse = try await apiClient.request(
        "GET",
        API.Lists.memberships(String(self.list.id)),
        body: nil as String?
      )
      self.memberships = response.memberships
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
        API.Lists.membership(String(self.list.id), String(membership.id)),
        body: nil as String?
      )
      self.memberships.removeAll { $0.id == membership.id }
      self.memberToRemove = nil
    } catch let err as FocusmateError {
      error = err
    } catch {
      self.error = ErrorHandler.shared.handle(error, context: "Removing member")
    }
  }

  func loadFriends() async {
    self.isLoadingFriends = true
    defer { isLoadingFriends = false }

    do {
      self.friends = try await self.friendService.fetchFriends()
    } catch {
      // Silently fail - friends are optional enhancement
      Logger.warning("Failed to load friends: \(error)", category: .api)
    }
  }

  func updateMemberRole(_ membership: MembershipDTO, newRole: String) async {
    let originalMemberships = self.memberships

    // Optimistic update
    if let idx = memberships.firstIndex(where: { $0.id == membership.id }) {
      let updated = MembershipDTO(
        id: membership.id,
        user: membership.user,
        role: newRole,
        created_at: membership.created_at,
        updated_at: membership.updated_at
      )
      self.memberships[idx] = updated
    }

    do {
      let response: MembershipResponse = try await apiClient.request(
        "PATCH",
        API.Lists.membership(String(self.list.id), String(membership.id)),
        body: UpdateMembershipRequest(membership: UpdateMembershipParams(role: newRole))
      )
      if let idx = memberships.firstIndex(where: { $0.id == response.membership.id }) {
        self.memberships[idx] = response.membership
      }
      HapticManager.success()
    } catch {
      self.memberships = originalMemberships
      self.error = ErrorHandler.shared.handle(error, context: "Updating member role")
      HapticManager.error()
    }
  }

  func addFriendToList(_ friend: FriendDTO) async {
    self.addingFriendId = friend.id
    defer { addingFriendId = nil }

    do {
      let membership = try await friendService.addFriendToList(
        listId: self.list.id,
        friendId: friend.id,
        role: self.selectedRole
      )
      self.memberships.append(membership)
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
