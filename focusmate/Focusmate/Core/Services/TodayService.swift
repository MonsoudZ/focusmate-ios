import Foundation

@MainActor
final class TodayService {
    private let api: APIClient
    private let cache = ResponseCache.shared

    private static let cacheKey = "today"
    private static var cacheTTL: TimeInterval { AppConfiguration.Cache.todayTTLSeconds }

    init(api: APIClient) {
        self.api = api
    }

    func fetchToday(ignoreCache: Bool = false) async throws -> TodayResponse {
        if !ignoreCache, let cached: TodayResponse = await cache.get(Self.cacheKey) {
            return cached
        }
        let response: TodayResponse = try await api.request("GET", API.Today.root, body: nil as String?)
        Logger.debug("TodayService: streak = \(String(describing: response.streak))", category: .api)
        await cache.set(Self.cacheKey, value: response, ttl: Self.cacheTTL)
        return response
    }

    func invalidateCache() async {
        await cache.invalidate(Self.cacheKey)
    }
}
