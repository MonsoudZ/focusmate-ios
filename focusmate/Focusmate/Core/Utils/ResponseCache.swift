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
      self.store.removeValue(forKey: key)
      return nil
    }

    // Update access time for LRU tracking
    entry.lastAccessed = Date()
    self.store[key] = entry

    return entry.value as? T
  }

  func set(_ key: String, value: some Any, ttl: TimeInterval) {
    // Evict LRU entry if at capacity
    if self.store.count >= self.maxEntries {
      self.evictLeastRecentlyUsed()
    }

    let now = Date()
    self.store[key] = Entry(
      value: value,
      expiration: now.addingTimeInterval(ttl),
      lastAccessed: now
    )
  }

  /// Atomically reads, transforms, and writes a cache entry.
  ///
  /// The entire read-modify-write runs inside a single actor-isolated method,
  /// so no other caller can interleave between the read and the write.
  /// Without this, doing `get → mutate locally → set` as separate calls
  /// creates a TOCTOU race: two concurrent writers both read the same
  /// snapshot, mutate independently, and the second `set` overwrites the
  /// first writer's changes.
  ///
  /// If the key is missing or expired, the transform is not called.
  func mutate<T>(_ key: String, ttl: TimeInterval, transform: (inout T) -> Void) {
    guard let entry = store[key] else { return }

    if Date() >= entry.expiration {
      self.store.removeValue(forKey: key)
      return
    }

    guard var value = entry.value as? T else { return }
    transform(&value)

    let now = Date()
    self.store[key] = Entry(
      value: value,
      expiration: now.addingTimeInterval(ttl),
      lastAccessed: now
    )
  }

  func invalidate(_ key: String) {
    self.store.removeValue(forKey: key)
  }

  func invalidateAll() {
    self.store.removeAll()
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
    self.store.removeValue(forKey: oldestKey)
  }

  // MARK: - Diagnostics (DEBUG only)

  #if DEBUG
    var entryCount: Int {
      self.store.count
    }

    var keys: [String] {
      Array(self.store.keys)
    }
  #endif
}
