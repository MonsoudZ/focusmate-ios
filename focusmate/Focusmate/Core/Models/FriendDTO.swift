import Foundation

struct FriendDTO: Codable, Identifiable, Hashable, Sendable {
  let id: Int
  let name: String?
  let email: String?

  var displayName: String {
    self.name ?? self.email ?? "Friend"
  }
}

struct FriendsResponse: Codable, Sendable {
  let friends: [FriendDTO]
}
