import Foundation

struct FriendDTO: Codable, Identifiable, Hashable {
  static func == (lhs: FriendDTO, rhs: FriendDTO) -> Bool { lhs.id == rhs.id }
  func hash(into hasher: inout Hasher) { hasher.combine(self.id) }

  let id: Int
  let name: String?
  let email: String?

  var displayName: String {
    self.name ?? self.email ?? "Friend"
  }
}

struct FriendsResponse: Codable {
  let friends: [FriendDTO]
}
