import Foundation

final class ListService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - List Management

    func fetchLists() async throws -> [ListDTO] {
        let response: ListsResponse = try await apiClient.request("GET", API.Lists.root, body: nil as String?)
        Logger.debug("ListService: Fetched \(response.lists.count) lists", category: .api)
        return response.lists
    }

    func fetchList(id: Int) async throws -> ListDTO {
        return try await apiClient.request("GET", API.Lists.id(String(id)), body: nil as String?)
    }

    func createList(name: String, description: String?, color: String = "blue") async throws -> ListDTO {
        let request = CreateListRequest(list: .init(name: name, description: description, color: color))
        return try await apiClient.request("POST", API.Lists.root, body: request)
    }

    func updateList(id: Int, name: String?, description: String?, color: String? = nil) async throws -> ListDTO {
        let request = UpdateListRequest(list: .init(name: name, description: description, visibility: nil, color: color))
        return try await apiClient.request("PUT", API.Lists.id(String(id)), body: request)
    }

    func deleteList(id: Int) async throws {
        _ = try await apiClient.request("DELETE", API.Lists.id(String(id)), body: nil as String?) as EmptyResponse
    }
}
