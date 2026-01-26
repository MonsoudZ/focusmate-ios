import Foundation

@MainActor
final class TodayService {
    private let api: APIClient
    private let cache = ResponseCache.shared

    private static let cacheKey = "today"
    private static let cacheTTL: TimeInterval = 10 // short TTL — data changes frequently

    init(api: APIClient) {
        self.api = api
    }

    func fetchToday(ignoreCache: Bool = false) async throws -> TodayResponse {
        if !ignoreCache, let cached: TodayResponse = await cache.get(Self.cacheKey) {
            return cached
        }
        let response: TodayResponse = try await api.request("GET", API.Today.root, body: nil as String?)
        await cache.set(Self.cacheKey, value: response, ttl: Self.cacheTTL)
        return response
    }

    func invalidateCache() async {
        await cache.invalidate(Self.cacheKey)
    }
}
