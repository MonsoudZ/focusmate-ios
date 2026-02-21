import Foundation

struct MembershipDTO: Codable, Identifiable, Hashable, Sendable {
  let id: Int
  let user: MemberUser
  let role: String
  let created_at: String?
  let updated_at: String?

  var isEditor: Bool {
    self.role == "editor"
  }

  var isOwner: Bool {
    self.role == "owner"
  }
}

struct MemberUser: Codable, Hashable, Sendable {
  let id: Int
  let email: String?
  let name: String?
}

struct MembershipsResponse: Codable, Sendable {
  let memberships: [MembershipDTO]
}

struct CreateMembershipRequest: Encodable, Sendable {
  let membership: MembershipParams
}

struct MembershipParams: Encodable, Sendable {
  let user_identifier: String
  let role: String
}

struct MembershipResponse: Codable, Sendable {
  let membership: MembershipDTO
}

struct UpdateMembershipRequest: Encodable, Sendable {
  let membership: UpdateMembershipParams
}

struct UpdateMembershipParams: Encodable, Sendable {
  let role: String
}
