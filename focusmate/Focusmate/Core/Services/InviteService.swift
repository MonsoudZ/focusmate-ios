import Foundation

@MainActor
final class InviteService {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  // MARK: - List Owner Operations

  /// Fetch all invites for a list
  func fetchInvites(listId: Int) async throws -> [InviteDTO] {
    try InputValidation.requirePositive(listId, fieldName: "list_id")
    let response: InvitesResponse = try await apiClient.request(
      "GET",
      API.Lists.invites(String(listId)),
      body: nil as String?
    )
    return response.invites
  }

  /// Create a new invite for a list
  func createInvite(
    listId: Int,
    role: String = "viewer",
    expiresAt: Date? = nil,
    maxUses: Int? = nil
  ) async throws -> InviteDTO {
    try InputValidation.requirePositive(listId, fieldName: "list_id")
    var expiresAtString: String?
    if let expiresAt {
      expiresAtString = ISO8601Utils.formatDateNoFrac(expiresAt)
    }

    let request = CreateInviteRequest(
      invite: .init(
        role: role,
        expires_at: expiresAtString,
        max_uses: maxUses
      )
    )

    let response: InviteResponse = try await apiClient.request(
      "POST",
      API.Lists.invites(String(listId)),
      body: request
    )
    return response.invite
  }

  /// Revoke an invite
  func revokeInvite(listId: Int, inviteId: Int) async throws {
    try InputValidation.requirePositive(listId, fieldName: "list_id")
    try InputValidation.requirePositive(inviteId, fieldName: "invite_id")
    let _: EmptyResponse = try await apiClient.request(
      "DELETE",
      API.Lists.invite(String(listId), String(inviteId)),
      body: nil as String?
    )
  }

  // MARK: - Invite Recipient Operations

  /// Preview an invite (no auth required)
  func previewInvite(code: String) async throws -> InvitePreviewDTO {
    try InputValidation.requireNotEmpty(code, fieldName: "code")
    let response: InvitePreviewResponse = try await apiClient.request(
      "GET",
      API.Invites.preview(code),
      body: nil as String?
    )
    return response.invite
  }

  /// Accept an invite (auth required)
  func acceptInvite(code: String) async throws -> AcceptInviteResponse {
    try InputValidation.requireNotEmpty(code, fieldName: "code")
    let response: AcceptInviteResponse = try await apiClient.request(
      "POST",
      API.Invites.accept(code),
      body: nil as String?
    )

    // Invalidate lists cache since user now has access to a new list
    await ResponseCache.shared.invalidate("lists")

    return response
  }
}
