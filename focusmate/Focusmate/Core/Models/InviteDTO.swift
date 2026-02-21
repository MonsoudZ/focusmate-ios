import Foundation

// MARK: - Invite DTO

struct InviteDTO: Codable, Identifiable, Hashable, Sendable {
  let id: Int
  let code: String
  let invite_url: String
  let role: String
  let uses_count: Int
  let max_uses: Int?
  let expires_at: String?
  let usable: Bool
  let created_at: String?

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
    switch self.role {
    case "editor": return "Can edit"
    case "viewer": return "View only"
    default: return self.role.capitalized
    }
  }

  var usageDescription: String {
    if let max = max_uses {
      return "\(self.uses_count)/\(max) uses"
    }
    return "\(self.uses_count) uses"
  }
}

// MARK: - Invite Preview (for unauthenticated preview)

struct InvitePreviewDTO: Codable, Hashable, Sendable {
  let code: String
  let role: String
  let list: InviteListInfo
  let inviter: InviterInfo?
  let usable: Bool
  let expired: Bool
  let exhausted: Bool

  struct InviteListInfo: Codable, Hashable, Sendable {
    let id: Int
    let name: String
    let color: String?
  }

  struct InviterInfo: Codable, Hashable, Sendable {
    let name: String
  }

  var listName: String {
    self.list.name
  }

  var inviterName: String? {
    self.inviter?.name
  }

  var roleDisplayName: String {
    switch self.role {
    case "editor": return "edit"
    case "viewer": return "view"
    default: return self.role
    }
  }
}

// MARK: - Request/Response Types

struct CreateInviteRequest: Encodable, Sendable {
  let invite: InviteParams

  struct InviteParams: Encodable, Sendable {
    let role: String
    let expires_at: String?
    let max_uses: Int?
  }
}

struct InviteResponse: Codable, Sendable {
  let invite: InviteDTO
}

struct InvitesResponse: Codable, Sendable {
  let invites: [InviteDTO]
}

struct InvitePreviewResponse: Codable, Sendable {
  let invite: InvitePreviewDTO
}

struct AcceptInviteResponse: Codable, Sendable {
  let list: ListDTO
  let membership: MembershipDTO
}
