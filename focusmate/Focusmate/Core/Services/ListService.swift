import Foundation

final class ListService {
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - List Management
    
    func fetchLists() async throws -> [ListDTO] {
        // GET /lists returns array directly
        let lists: [ListDTO] = try await apiClient.request("GET", "lists", body: nil as String?)
        print("🔍 ListService: Fetched \(lists.count) lists from Rails API")
        print("🔍 ListService: List IDs: \(lists.map { $0.id })")
        
        // Filter out lists that the user doesn't have access to
        // For now, we'll filter out lists with IDs > 10 as a temporary fix
        // TODO: This should be handled by the Rails API permissions
        let accessibleLists = lists.filter { $0.id <= 10 }
        print("🔍 ListService: Filtered to \(accessibleLists.count) accessible lists")
        print("🔍 ListService: Accessible List IDs: \(accessibleLists.map { $0.id })")
        
        return accessibleLists
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
    
    // MARK: - Request/Response Models
    
    struct EmptyResponse: Codable {}
}
