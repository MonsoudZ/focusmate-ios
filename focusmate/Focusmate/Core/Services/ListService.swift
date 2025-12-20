import Foundation

final class ListService {
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - List Management
    
    func fetchLists() async throws -> [ListDTO] {
        let response = try await apiClient.request("GET", API.Lists.root, body: nil)
        let lists = response.lists
        Logger.debug("ListService: Fetched \(lists.count) lists from Rails API", category: .database)
        return lists
    }
    
    func fetchList(id: Int) async throws -> ListDTO {
        return try await self.apiClient.request("GET", API.Lists.id(String(id)), body: nil as String?)
    }
    
    func createList(name: String, description: String?) async throws -> ListDTO {
        let request = CreateListRequest(list: .init(name: name, description: description, visibility: "private"))
        return try await self.apiClient.request("POST", API.Lists.root, body: request)
    }
    
    func updateList(id: Int, name: String?, description: String?) async throws -> ListDTO {
        let request = UpdateListRequest(list: .init(name: name, description: description, visibility: nil))
        return try await self.apiClient.request("PUT", API.Lists.id(String(id)), body: request)
    }
    
    func deleteList(id: Int) async throws {
        _ = try await self.apiClient.request("DELETE", API.Lists.root, body: nil) as AnyResponse
    }
    
    // MARK: - List Sharing
    
    func shareList(id: Int, request: ShareListRequest) async throws -> ShareListResponse {
        return try await self.apiClient.request("POST", "\(API.Lists.id(String(id)))/share", body: request)
    }
    
    func fetchShares(listId: Int) async throws -> [ListShare] {
        return try await self.apiClient.request("GET", "\(API.Lists.id(String(listId)))/shares", body: nil as String?)
    }
    
    func removeShare(listId: Int, shareId: Int) async throws {
        _ = try await self.apiClient.request(
            "DELETE",
            "\(API.Lists.id(String(listId)))/shares/\(shareId)",
            body: nil as String?
        ) as EmptyResponse
    }
}
