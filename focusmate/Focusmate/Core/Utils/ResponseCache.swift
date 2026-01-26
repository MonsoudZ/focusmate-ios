import Foundation

/// Lightweight in-memory cache with time-based expiration.
/// Thread-safe via actor isolation.
actor ResponseCache {
    static let shared = ResponseCache()

    private struct Entry {
        let value: Any
        let expiration: Date
    }

    private var store: [String: Entry] = [:]

    func get<T>(_ key: String) -> T? {
        guard let entry = store[key], Date() < entry.expiration else {
            store.removeValue(forKey: key)
            return nil
        }
        return entry.value as? T
    }

    func set<T>(_ key: String, value: T, ttl: TimeInterval) {
        store[key] = Entry(value: value, expiration: Date().addingTimeInterval(ttl))
    }

    func invalidate(_ key: String) {
        store.removeValue(forKey: key)
    }

    func invalidateAll() {
        store.removeAll()
    }
}
