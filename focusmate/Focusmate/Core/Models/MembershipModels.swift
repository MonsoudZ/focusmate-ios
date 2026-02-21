import Foundation

struct MembershipDTO: Codable, Identifiable, Hashable {
  static func == (lhs: MembershipDTO, rhs: MembershipDTO) -> Bool { lhs.id == rhs.id }
  func hash(into hasher: inout Hasher) { hasher.combine(self.id) }

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

struct MemberUser: Codable, Hashable {
  let id: Int
  let email: String?
  let name: String?
}

struct MembershipsResponse: Codable {
  let memberships: [MembershipDTO]
}

struct CreateMembershipRequest: Codable {
  let membership: MembershipParams
}

struct MembershipParams: Codable {
  let user_identifier: String
  let role: String
}

struct MembershipResponse: Codable {
  let membership: MembershipDTO
}

struct UpdateMembershipRequest: Codable {
  let membership: UpdateMembershipParams
}

struct UpdateMembershipParams: Codable {
  let role: String
}
