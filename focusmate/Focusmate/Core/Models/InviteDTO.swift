import Foundation

// MARK: - Invite DTO

struct InviteDTO: Codable, Identifiable {
    let id: Int
    let code: String
    let invite_url: String
    let role: String
    let uses_count: Int
    let max_uses: Int?
    let expires_at: String?
    let usable: Bool

    var isExpired: Bool {
        guard let expires_at else { return false }
        guard let date = ISO8601Utils.parseDate(expires_at) else { return false }
        return date < Date()
    }

    var expiresDate: Date? {
        guard let expires_at else { return nil }
        return ISO8601Utils.parseDate(expires_at)
    }

    var roleDisplayName: String {
        switch role {
        case "editor": return "Can edit"
        case "viewer": return "View only"
        default: return role.capitalized
        }
    }

    var usageDescription: String {
        if let max = max_uses {
            return "\(uses_count)/\(max) uses"
        }
        return "\(uses_count) uses"
    }
}

// MARK: - Invite Preview (for unauthenticated preview)

struct InvitePreviewDTO: Codable {
    let code: String
    let role: String
    let list: InviteListInfo
    let inviter: InviterInfo?
    let usable: Bool
    let expired: Bool
    let exhausted: Bool

    struct InviteListInfo: Codable {
        let id: Int
        let name: String
        let color: String
    }

    struct InviterInfo: Codable {
        let name: String
    }

    var listName: String { list.name }
    var inviterName: String? { inviter?.name }

    var roleDisplayName: String {
        switch role {
        case "editor": return "edit"
        case "viewer": return "view"
        default: return role
        }
    }
}

// MARK: - Request/Response Types

struct CreateInviteRequest: Encodable {
    let invite: InviteParams

    struct InviteParams: Encodable {
        let role: String
        let expires_at: String?
        let max_uses: Int?
    }
}

struct InviteResponse: Codable {
    let invite: InviteDTO
}

struct InvitesResponse: Codable {
    let invites: [InviteDTO]
}

struct InvitePreviewResponse: Codable {
    let invite: InvitePreviewDTO
}

struct AcceptInviteResponse: Codable {
    let list: ListDTO
    let membership: MembershipDTO
}
