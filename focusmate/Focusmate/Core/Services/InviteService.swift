import Foundation

final class InviteService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Input Validation

    private func validateListId(_ listId: Int) throws {
        guard listId > 0 else {
            throw FocusmateError.validation(["list_id": ["must be a positive number"]], nil)
        }
    }

    private func validateInviteId(_ inviteId: Int) throws {
        guard inviteId > 0 else {
            throw FocusmateError.validation(["invite_id": ["must be a positive number"]], nil)
        }
    }

    private func validateInviteCode(_ code: String) throws {
        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FocusmateError.validation(["code": ["cannot be empty"]], nil)
        }
    }

    // MARK: - List Owner Operations

    /// Fetch all invites for a list
    func fetchInvites(listId: Int) async throws -> [InviteDTO] {
        try validateListId(listId)
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
        try validateListId(listId)
        var expiresAtString: String?
        if let expiresAt {
            expiresAtString = ISO8601DateFormatter().string(from: expiresAt)
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
        try validateListId(listId)
        try validateInviteId(inviteId)
        let _: EmptyResponse = try await apiClient.request(
            "DELETE",
            API.Lists.invite(String(listId), String(inviteId)),
            body: nil as String?
        )
    }

    // MARK: - Invite Recipient Operations

    /// Preview an invite (no auth required)
    func previewInvite(code: String) async throws -> InvitePreviewDTO {
        try validateInviteCode(code)
        let response: InvitePreviewResponse = try await apiClient.request(
            "GET",
            API.Invites.preview(code),
            body: nil as String?
        )
        return response.invite
    }

    /// Accept an invite (auth required)
    func acceptInvite(code: String) async throws -> AcceptInviteResponse {
        try validateInviteCode(code)
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
