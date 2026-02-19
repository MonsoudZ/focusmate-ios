@testable import focusmate
import XCTest

final class ResponseCacheTests: XCTestCase {
  private var cache: ResponseCache!

  override func setUp() async throws {
    try await super.setUp()
    self.cache = ResponseCache.shared
    await self.cache.invalidateAll()
  }

  override func tearDown() async throws {
    await self.cache.invalidateAll()
    try await super.tearDown()
  }

  // MARK: - Basic Get/Set

  func testSetAndGetValue() async {
    await self.cache.set("key1", value: "hello", ttl: 60)
    let result: String? = await cache.get("key1")
    XCTAssertEqual(result, "hello")
  }

  func testGetReturnsNilForMissingKey() async {
    let result: String? = await cache.get("nonexistent")
    XCTAssertNil(result)
  }

  // MARK: - TTL Expiration

  func testTTLExpiration() async throws {
    await self.cache.set("expiring", value: "data", ttl: 0.1)

    // Immediately available
    let before: String? = await cache.get("expiring")
    XCTAssertEqual(before, "data")

    // Wait for expiration
    try await Task.sleep(nanoseconds: 200_000_000) // 0.2s

    let after: String? = await cache.get("expiring")
    XCTAssertNil(after)
  }

  // MARK: - Invalidation

  func testInvalidateSingleKey() async {
    await self.cache.set("a", value: 1, ttl: 60)
    await self.cache.set("b", value: 2, ttl: 60)

    await self.cache.invalidate("a")

    let a: Int? = await cache.get("a")
    let b: Int? = await cache.get("b")
    XCTAssertNil(a)
    XCTAssertEqual(b, 2)
  }

  func testInvalidateAllKeys() async {
    await self.cache.set("x", value: 10, ttl: 60)
    await self.cache.set("y", value: 20, ttl: 60)

    await self.cache.invalidateAll()

    let x: Int? = await cache.get("x")
    let y: Int? = await cache.get("y")
    XCTAssertNil(x)
    XCTAssertNil(y)
  }

  // MARK: - Type Mismatch

  func testTypeMismatchReturnsNil() async {
    await self.cache.set("typed", value: "a string", ttl: 60)
    let result: Int? = await cache.get("typed")
    XCTAssertNil(result)
  }

  // MARK: - Overwrite

  func testOverwriteExistingKey() async {
    await self.cache.set("key", value: "old", ttl: 60)
    await self.cache.set("key", value: "new", ttl: 60)
    let result: String? = await cache.get("key")
    XCTAssertEqual(result, "new")
  }

  // MARK: - Complex Types

  func testCacheArrayOfDTOs() async {
    let lists = [
      TestFactories.makeSampleList(id: 1, name: "A"),
      TestFactories.makeSampleList(id: 2, name: "B"),
    ]
    await self.cache.set("lists", value: lists, ttl: 60)
    let result: [ListDTO]? = await cache.get("lists")
    XCTAssertEqual(result?.count, 2)
    XCTAssertEqual(result?.first?.name, "A")
  }
}
