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
        print("🔍 ListService: Fetched \(lists.count) lists from Rails API")
        print("🔍 ListService: List IDs: \(lists.map { $0.id })")
        
        // Return all lists - the API should handle permissions
        print("🔍 ListService: Returning \(lists.count) lists")
        print("🔍 ListService: List IDs: \(lists.map { $0.id })")
        
        return lists
    }
    
    func fetchList(id: Int) async throws -> ListDTO {
        // GET /lists/:id returns single object directly
        return try await apiClient.request("GET", "lists/\(id)", body: nil as String?)
    }
    
    func createList(name: String, description: String?) async throws -> ListDTO {
        let request = CreateListRequest(name: name, description: description)
        // POST /lists returns single object directly
        return try await apiClient.request("POST", "lists", body: request)
    }
    
    func updateList(id: Int, name: String?, description: String?) async throws -> ListDTO {
        let request = UpdateListRequest(name: name, description: description)
        // PUT /lists/:id returns single object directly
        return try await apiClient.request("PUT", "lists/\(id)", body: request)
    }
    
    func deleteList(id: Int) async throws {
        _ = try await apiClient.request("DELETE", "lists/\(id)", body: nil as String?) as EmptyResponse
    }
    
    // MARK: - List Sharing
    
    func shareList(id: Int, request: ShareListRequest) async throws -> ShareListResponse {
        return try await apiClient.request("POST", "lists/\(id)/share", body: request)
    }
    
    func fetchShares(listId: Int) async throws -> [ListShare] {
        return try await apiClient.request("GET", "lists/\(listId)/shares", body: nil as String?)
    }
    
    func removeShare(listId: Int, shareId: Int) async throws {
        _ = try await apiClient.request("DELETE", "lists/\(listId)/shares/\(shareId)", body: nil as String?) as EmptyResponse
    }
    
    // MARK: - Request/Response Models
    
    struct EmptyResponse: Codable {}
    
    struct ListsResponse: Codable {
        let lists: [ListDTO]
        let tombstones: [String]?
    }
}
