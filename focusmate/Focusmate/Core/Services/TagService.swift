import Foundation

@MainActor
final class TagService {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  func fetchTags() async throws -> [TagDTO] {
    let response: TagsResponse = try await apiClient.request(
      "GET",
      API.Tags.root,
      body: nil as String?
    )
    return response.tags
  }

  func createTag(name: String, color: String?) async throws -> TagDTO {
    let request = CreateTagRequest(tag: .init(name: name, color: color))
    return try await self.apiClient.request(
      "POST",
      API.Tags.root,
      body: request
    )
  }

  func updateTag(id: Int, name: String?, color: String?) async throws -> TagDTO {
    let request = UpdateTagRequest(tag: .init(name: name, color: color))
    return try await self.apiClient.request(
      "PATCH",
      API.Tags.id(String(id)),
      body: request
    )
  }

  func deleteTag(id: Int) async throws {
    _ = try await self.apiClient.request(
      "DELETE",
      API.Tags.id(String(id)),
      body: nil as String?
    ) as EmptyResponse
  }
}

private struct CreateTagRequest: Encodable {
  let tag: TagData
  struct TagData: Encodable {
    let name: String
    let color: String?
  }
}

private struct UpdateTagRequest: Encodable {
  let tag: TagData
  struct TagData: Encodable {
    let name: String?
    let color: String?
  }
}
