import Foundation

@MainActor
final class TodayService {
    private let api: APIClient
    
    init(api: APIClient) {
        self.api = api
    }
    
    func fetchToday() async throws -> TodayResponse {
        try await api.request("GET", API.Today.root, body: nil as String?)
    }
}
