import Foundation

final class ListService {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  // MARK: - List Management

  func fetchLists() async throws -> [ListDTO] {
    // GET /lists returns object with lists array
    let response: ListsResponse = try await apiClient.request("GET", "lists", body: nil as String?)
    let lists = response.lists
    #if DEBUG
    print("🔍 ListService: Fetched \(lists.count) lists from Rails API")
    #endif
    #if DEBUG
    print("🔍 ListService: List IDs: \(lists.map(\.id))")
    #endif

    // Return all lists - the API should handle permissions
    #if DEBUG
    print("🔍 ListService: Returning \(lists.count) lists")
    #endif
    #if DEBUG
    print("🔍 ListService: List IDs: \(lists.map(\.id))")
    #endif

    return lists
  }

  func fetchList(id: Int) async throws -> ListDTO {
    // GET /lists/:id returns single object directly
    return try await self.apiClient.request("GET", "lists/\(id)", body: nil as String?)
  }

  func createList(name: String, description: String?) async throws -> ListDTO {
    let request = CreateListRequest(list: .init(name: name, description: description, visibility: "private"))
    // POST /lists returns single object directly
    return try await self.apiClient.request("POST", "lists", body: request)
  }

  func updateList(id: Int, name: String?, description: String?) async throws -> ListDTO {
    let request = UpdateListRequest(list: .init(name: name, description: description, visibility: nil))
    // PUT /lists/:id returns single object directly
    return try await self.apiClient.request("PUT", "lists/\(id)", body: request)
  }

  func deleteList(id: Int) async throws {
    // Use AnyResponse to accept whatever Rails returns (could be deleted object, message, or empty)
    _ = try await self.apiClient.request("DELETE", "lists/\(id)", body: nil as String?) as AnyResponse
  }

  // MARK: - List Sharing

  func shareList(id: Int, request: ShareListRequest) async throws -> ShareListResponse {
    return try await self.apiClient.request("POST", "lists/\(id)/share", body: request)
  }

  func fetchShares(listId: Int) async throws -> [ListShare] {
    return try await self.apiClient.request("GET", "lists/\(listId)/shares", body: nil as String?)
  }

  func removeShare(listId: Int, shareId: Int) async throws {
    _ = try await self.apiClient.request(
      "DELETE",
      "lists/\(listId)/shares/\(shareId)",
      body: nil as String?
    ) as EmptyResponse
  }

  // MARK: - Request/Response Models

  struct EmptyResponse: Codable {}

  // Response type that accepts any JSON structure OR empty response - useful for DELETE endpoints
  struct AnyResponse: Codable {
    init(from decoder: Decoder) throws {
      // Try to decode as dictionary, array, or any value
      // If all fail, that's OK - the response might be empty
      if let container = try? decoder.singleValueContainer() {
        _ = try? container.decode([String: AnyCodable].self)
      }
      // Even if decoding fails, init succeeds - we just want to accept the response
    }

    init() {}
  }

  // Helper to decode any JSON value
  private struct AnyCodable: Codable {
    let value: Any

    init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      if let int = try? container.decode(Int.self) {
        value = int
      } else if let string = try? container.decode(String.self) {
        value = string
      } else if let bool = try? container.decode(Bool.self) {
        value = bool
      } else if let dict = try? container.decode([String: AnyCodable].self) {
        value = dict
      } else if let array = try? container.decode([AnyCodable].self) {
        value = array
      } else {
        value = ""
      }
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.singleValueContainer()
      switch value {
      case let int as Int:
        try container.encode(int)
      case let string as String:
        try container.encode(string)
      case let bool as Bool:
        try container.encode(bool)
      default:
        try container.encode("")
      }
    }
  }

  struct ListsResponse: Codable {
    let lists: [ListDTO]
    let tombstones: [String]?
  }
}
