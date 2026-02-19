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

    private var loadVersion = 0

    func loadInvites() async {
        loadVersion += 1
        let myVersion = loadVersion

        isLoading = invites.isEmpty
        error = nil

        do {
            let result = try await inviteService.fetchInvites(listId: list.id)
            guard myVersion == loadVersion else { return }
            invites = result
        } catch let err as FocusmateError {
            guard myVersion == loadVersion else { return }
            error = err
        } catch {
            guard myVersion == loadVersion else { return }
            self.error = ErrorHandler.shared.handle(error, context: "Loading invites")
        }

        guard myVersion == loadVersion else { return }
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
            self.error = ErrorHandler.shared.handle(error, context: "Creating invite")
            HapticManager.error()
        }
        return nil
    }

    func revokeInvite(_ invite: InviteDTO) async {
        // Optimistic: remove immediately for responsive UI
        let snapshot = invites
        invites.removeAll { $0.id == invite.id }
        HapticManager.medium()

        do {
            try await inviteService.revokeInvite(listId: list.id, inviteId: invite.id)
            // Reload to ensure server state consistency
            await loadInvites()
        } catch {
            // Revert optimistic removal on failure
            invites = snapshot
            if let err = error as? FocusmateError {
                self.error = err
            } else {
                self.error = ErrorHandler.shared.handle(error, context: "Revoking invite")
            }
            HapticManager.error()
        }
    }
}
