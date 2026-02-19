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
    self.loadVersion += 1
    let myVersion = self.loadVersion

    self.isLoading = self.invites.isEmpty
    self.error = nil

    do {
      let result = try await inviteService.fetchInvites(listId: self.list.id)
      guard myVersion == self.loadVersion else { return }
      self.invites = result
    } catch let err as FocusmateError {
      guard myVersion == loadVersion else { return }
      error = err
    } catch {
      guard myVersion == self.loadVersion else { return }
      self.error = ErrorHandler.shared.handle(error, context: "Loading invites")
    }

    guard myVersion == self.loadVersion else { return }
    self.isLoading = false
  }

  func createInvite(role: String, expiresAt: Date?, maxUses: Int?) async -> InviteDTO? {
    do {
      let invite = try await inviteService.createInvite(
        listId: self.list.id,
        role: role,
        expiresAt: expiresAt,
        maxUses: maxUses
      )
      self.invites.insert(invite, at: 0)
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
    let snapshot = self.invites
    self.invites.removeAll { $0.id == invite.id }
    HapticManager.medium()

    do {
      try await self.inviteService.revokeInvite(listId: self.list.id, inviteId: invite.id)
      // Reload to ensure server state consistency
      await self.loadInvites()
    } catch {
      // Revert optimistic removal on failure
      self.invites = snapshot
      if let err = error as? FocusmateError {
        self.error = err
      } else {
        self.error = ErrorHandler.shared.handle(error, context: "Revoking invite")
      }
      HapticManager.error()
    }
  }
}
