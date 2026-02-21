import Foundation

struct FriendDTO: Codable, Identifiable, Hashable {
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
