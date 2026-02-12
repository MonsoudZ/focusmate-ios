import Foundation

final class ListService {
    private let apiClient: APIClient
    private let cache = ResponseCache.shared

    private static let cacheKey = "lists"
    private static var cacheTTL: TimeInterval { AppConfiguration.Cache.listsTTLSeconds }

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - List Management

    func fetchLists() async throws -> [ListDTO] {
        if let cached: [ListDTO] = await cache.get(Self.cacheKey) {
            return cached
        }
        let response: ListsResponse = try await apiClient.request("GET", API.Lists.root, body: nil as String?)
        Logger.debug("ListService: Fetched \(response.lists.count) lists", category: .api)
        await cache.set(Self.cacheKey, value: response.lists, ttl: Self.cacheTTL)
        return response.lists
    }

    func fetchList(id: Int) async throws -> ListDTO {
        let response: ListResponse = try await apiClient.request("GET", API.Lists.id(String(id)), body: nil as String?)
        return response.list
    }

    func createList(name: String, description: String?, color: String = "blue", tagIds: [Int] = []) async throws -> ListDTO {
        let request = CreateListRequest(list: .init(name: name, description: description, color: color, tagIds: tagIds))
        let response: ListResponse = try await apiClient.request("POST", API.Lists.root, body: request)
        // Write-through: append to cached list so concurrent reads stay consistent.
        // If cache is empty (cold start), skip — next fetchLists will populate it.
        if var cached: [ListDTO] = await cache.get(Self.cacheKey) {
            cached.append(response.list)
            await cache.set(Self.cacheKey, value: cached, ttl: Self.cacheTTL)
        }
        return response.list
    }

    func updateList(id: Int, name: String?, description: String?, color: String? = nil, tagIds: [Int]? = nil) async throws -> ListDTO {
        let request = UpdateListRequest(list: .init(name: name, description: description, visibility: nil, color: color, tag_ids: tagIds))
        let response: ListResponse = try await apiClient.request("PUT", API.Lists.id(String(id)), body: request)
        // Write-through: replace the updated list in-place.
        if var cached: [ListDTO] = await cache.get(Self.cacheKey) {
            if let idx = cached.firstIndex(where: { $0.id == id }) {
                cached[idx] = response.list
            }
            await cache.set(Self.cacheKey, value: cached, ttl: Self.cacheTTL)
        }
        return response.list
    }

    func deleteList(id: Int) async throws {
        _ = try await apiClient.request("DELETE", API.Lists.id(String(id)), body: nil as String?) as EmptyResponse
        // Write-through: remove from cached list.
        if var cached: [ListDTO] = await cache.get(Self.cacheKey) {
            cached.removeAll { $0.id == id }
            await cache.set(Self.cacheKey, value: cached, ttl: Self.cacheTTL)
        }
    }
}
