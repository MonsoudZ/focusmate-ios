import Foundation

@MainActor
@Observable
final class ListInvitesViewModel {
    var invites: [InviteDTO] = []
    var isLoading = true
    var error: FocusmateError?

    let list: ListDTO
    private let inviteService: InviteService

    init(list: ListDTO, inviteService: InviteService) {
        self.list = list
        self.inviteService = inviteService
    }

    func loadInvites() async {
        isLoading = true
        error = nil

        do {
            invites = try await inviteService.fetchInvites(listId: list.id)
        } catch let err as FocusmateError {
            error = err
        } catch {
            self.error = .custom("INVITES_ERROR", "Failed to load invites")
        }

        isLoading = false
    }

    func createInvite(role: String, expiresAt: Date?, maxUses: Int?) async -> InviteDTO? {
        do {
            let invite = try await inviteService.createInvite(
                listId: list.id,
                role: role,
                expiresAt: expiresAt,
                maxUses: maxUses
            )
            invites.insert(invite, at: 0)
            HapticManager.success()
            return invite
        } catch let err as FocusmateError {
            error = err
            HapticManager.error()
        } catch {
            self.error = .custom("INVITE_ERROR", "Failed to create invite")
            HapticManager.error()
        }
        return nil
    }

    func revokeInvite(_ invite: InviteDTO) async {
        do {
            try await inviteService.revokeInvite(listId: list.id, inviteId: invite.id)
            invites.removeAll { $0.id == invite.id }
            HapticManager.medium()
        } catch let err as FocusmateError {
            error = err
            HapticManager.error()
        } catch {
            self.error = .custom("INVITE_ERROR", "Failed to revoke invite")
            HapticManager.error()
        }
    }
}
