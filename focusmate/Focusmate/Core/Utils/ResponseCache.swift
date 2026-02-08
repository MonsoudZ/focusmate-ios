import Foundation

/// Lightweight in-memory cache with time-based expiration and LRU eviction.
/// Thread-safe via actor isolation.
///
/// ## Memory Management
/// The cache uses a bounded capacity with LRU (Least Recently Used) eviction.
/// When the cache reaches `maxEntries`, the oldest accessed entry is evicted
/// before inserting a new one. This prevents unbounded memory growth that would
/// otherwise occur with long-running sessions making many API calls.
///
/// ## Tradeoff
/// Bounded capacity means cache misses when entries are evicted. The default
/// capacity of 50 entries is tuned for typical usage (10-20 lists, ~100 tasks).
/// If cache miss rate is high, increase `maxEntries` at cost of memory.
actor ResponseCache {
    static let shared = ResponseCache()

    private struct Entry {
        let value: Any
        let expiration: Date
        var lastAccessed: Date
    }

    private var store: [String: Entry] = [:]

    /// Maximum number of entries before LRU eviction triggers.
    /// Each entry is typically 1-10KB (serialized API response).
    /// 50 entries ≈ 500KB max memory footprint.
    private let maxEntries = 50

    func get<T>(_ key: String) -> T? {
        guard var entry = store[key] else { return nil }

        // Check expiration
        if Date() >= entry.expiration {
            store.removeValue(forKey: key)
            return nil
        }

        // Update access time for LRU tracking
        entry.lastAccessed = Date()
        store[key] = entry

        return entry.value as? T
    }

    func set<T>(_ key: String, value: T, ttl: TimeInterval) {
        // Evict LRU entry if at capacity
        if store.count >= maxEntries {
            evictLeastRecentlyUsed()
        }

        let now = Date()
        store[key] = Entry(
            value: value,
            expiration: now.addingTimeInterval(ttl),
            lastAccessed: now
        )
    }

    func invalidate(_ key: String) {
        store.removeValue(forKey: key)
    }

    func invalidateAll() {
        store.removeAll()
    }

    // MARK: - LRU Eviction

    /// Removes the least recently accessed entry.
    /// Called when cache is at capacity before inserting a new entry.
    ///
    /// Complexity: O(n) where n = number of entries. Acceptable because
    /// eviction is infrequent (only when cache is full) and n is bounded.
    private func evictLeastRecentlyUsed() {
        guard let oldestKey = store.min(by: { $0.value.lastAccessed < $1.value.lastAccessed })?.key else {
            return
        }
        store.removeValue(forKey: oldestKey)
    }

    // MARK: - Diagnostics (DEBUG only)

    #if DEBUG
    var entryCount: Int { store.count }
    var keys: [String] { Array(store.keys) }
    #endif
}
