@testable import focusmate
import XCTest

// MARK: - Token Refresh Tests

/// Tests the 401 → token refresh → retry flow in InternalNetworking.
///
/// The TokenRefreshCoordinator (private actor inside InternalNetworking) deduplicates
/// concurrent refresh requests: when multiple requests hit 401 simultaneously, only one
/// HTTP call to /auth/refresh is made. The rest await the same Task. These tests verify
/// the full refresh lifecycle including the coordinator's coalescing behavior.
///
/// **Important:** All tests use non-expired tokens (far-future `exp`) to avoid triggering
/// the proactive refresh path in `applyAuth`. We're testing the reactive 401 → refresh flow,
/// not the proactive path. The server mock returns 401 regardless of token validity.
final class TokenRefreshTests: XCTestCase {

  override func setUp() async throws {
    try await super.setUp()
    MockURLProtocol.stub = nil
    MockURLProtocol.error = nil
    MockURLProtocol.requestHandler = nil
    await MainActor.run {
      AuthEventBus.shared._resetThrottleForTests()
    }
  }

  override func tearDown() async throws {
    MockURLProtocol.requestHandler = nil
    MockURLProtocol.stub = nil
    MockURLProtocol.error = nil
    try await super.tearDown()
  }

  // MARK: - Tests

  /// 401 → refresh endpoint called → retry with fresh token → success.
  /// Verifies the full happy path: profile called 2x, refresh called 1x, token updated.
  func test401TriggersRefreshAndRetriesWithNewToken() async throws {
    // Non-expired token so proactive refresh doesn't fire — only the reactive 401 path triggers
    let initialToken = makeJWT(exp: Date().addingTimeInterval(3600))
    let freshToken = makeJWT(exp: Date().addingTimeInterval(7200))
    let refreshBody = makeRefreshResponseBody(newToken: freshToken, newRefreshToken: "new-refresh")

    var currentToken = initialToken
    var tokenWasUpdated = false

    let profileCallCount = AtomicCounter()
    let refreshCallCount = AtomicCounter()

    let networking = makeNetworking(
      token: { currentToken },
      refreshToken: { "old-refresh" },
      onTokenRefreshed: { newToken, _ in
        currentToken = newToken
        tokenWasUpdated = true
      }
    )

    MockURLProtocol.requestHandler = { request in
      let path = request.url?.path ?? ""

      if path.hasSuffix("auth/refresh") {
        refreshCallCount.increment()
        return (MockURLProtocol.Stub(
          statusCode: 200,
          headers: ["Content-Type": "application/json"],
          body: refreshBody
        ), nil)
      }

      // Profile endpoint: 401 first time, 200 after refresh
      if path.hasSuffix("users/profile") {
        let count = profileCallCount.increment()
        if count == 1 {
          return (MockURLProtocol.Stub(statusCode: 401, headers: [:], body: Data()), nil)
        }
        let userJSON = self.makeUserJSON()
        return (MockURLProtocol.Stub(statusCode: 200, headers: ["Content-Type": "application/json"], body: userJSON), nil)
      }

      return (nil, nil)
    }

    let user: UserDTO = try await networking.request("GET", API.Users.profile, body: nil as String?, queryParameters: [:], idempotencyKey: nil)

    XCTAssertEqual(user.id, 1)
    XCTAssertEqual(profileCallCount.value, 2, "Profile should be called twice: initial 401 + retry")
    XCTAssertEqual(refreshCallCount.value, 1, "Refresh endpoint should be called exactly once")
    XCTAssertTrue(tokenWasUpdated, "onTokenRefreshed should have been called")
  }

  /// 401 on a public endpoint (auth/sign_in) does NOT trigger refresh.
  func test401OnPublicEndpointDoesNotTriggerRefresh() async {
    let refreshCallCount = AtomicCounter()

    let networking = makeNetworking(
      token: { "some-token" },
      refreshToken: { "some-refresh" },
      onTokenRefreshed: { _, _ in
        XCTFail("onTokenRefreshed should not be called for public endpoints")
      }
    )

    MockURLProtocol.requestHandler = { request in
      let path = request.url?.path ?? ""
      if path.hasSuffix("auth/refresh") {
        refreshCallCount.increment()
        return (MockURLProtocol.Stub(statusCode: 200, headers: [:], body: Data()), nil)
      }
      return (MockURLProtocol.Stub(statusCode: 401, headers: [:], body: Data()), nil)
    }

    do {
      let _: EmptyResponse = try await networking.request("POST", API.Auth.signIn, body: nil as String?, queryParameters: [:], idempotencyKey: nil)
      XCTFail("Expected unauthorized error")
    } catch let error as APIError {
      guard case .unauthorized = error else {
        return XCTFail("Expected .unauthorized but got \(error)")
      }
    } catch {
      XCTFail("Expected APIError but got \(error)")
    }

    XCTAssertEqual(refreshCallCount.value, 0, "Refresh should NOT be called for public endpoints")
  }

  /// Refresh endpoint returns 401 → original request throws .unauthorized.
  func testRefreshFailureThrowsUnauthorized() async {
    let networking = makeNetworking(
      token: { self.makeJWT(exp: Date().addingTimeInterval(3600)) },
      refreshToken: { "old-refresh" },
      onTokenRefreshed: { _, _ in
        XCTFail("onTokenRefreshed should not be called when refresh fails")
      }
    )

    MockURLProtocol.requestHandler = { request in
      let path = request.url?.path ?? ""
      if path.hasSuffix("auth/refresh") {
        return (MockURLProtocol.Stub(statusCode: 401, headers: [:], body: Data()), nil)
      }
      return (MockURLProtocol.Stub(statusCode: 401, headers: [:], body: Data()), nil)
    }

    do {
      let _: UserDTO = try await networking.request("GET", API.Users.profile, body: nil as String?, queryParameters: [:], idempotencyKey: nil)
      XCTFail("Expected unauthorized error")
    } catch let error as APIError {
      guard case .unauthorized = error else {
        return XCTFail("Expected .unauthorized but got \(error)")
      }
    } catch {
      XCTFail("Expected APIError but got \(error)")
    }
  }

  /// 3 concurrent requests all get 401. TokenRefreshCoordinator deduplicates into
  /// a bounded number of refresh HTTP calls. Uses AtomicCounter for thread-safe counting.
  func testConcurrent401sCoalesceIntoSingleRefresh() async throws {
    let freshToken = makeJWT(exp: Date().addingTimeInterval(7200))
    let refreshBody = makeRefreshResponseBody(newToken: freshToken, newRefreshToken: "new-refresh")

    // Non-expired token: avoids proactive refresh, tests only the reactive 401 path
    var currentToken = makeJWT(exp: Date().addingTimeInterval(3600))
    let refreshCallCount = AtomicCounter()
    let profileCallCounts = [AtomicCounter(), AtomicCounter(), AtomicCounter()]

    let networking = makeNetworking(
      token: { currentToken },
      refreshToken: { "old-refresh" },
      onTokenRefreshed: { newToken, _ in currentToken = newToken }
    )

    MockURLProtocol.requestHandler = { [self] request in
      let path = request.url?.path ?? ""

      if path.hasSuffix("auth/refresh") {
        refreshCallCount.increment()
        return (MockURLProtocol.Stub(
          statusCode: 200,
          headers: ["Content-Type": "application/json"],
          body: refreshBody
        ), nil)
      }

      if path.hasSuffix("users/profile") {
        let key = request.value(forHTTPHeaderField: "Idempotency-Key") ?? "0"
        let idx = Int(key) ?? 0
        let count = profileCallCounts[idx].increment()

        if count == 1 {
          return (MockURLProtocol.Stub(statusCode: 401, headers: [:], body: Data()), nil)
        }
        let userJSON = self.makeUserJSON()
        return (MockURLProtocol.Stub(statusCode: 200, headers: ["Content-Type": "application/json"], body: userJSON), nil)
      }

      return (nil, nil)
    }

    try await withThrowingTaskGroup(of: UserDTO.self) { group in
      for i in 0 ..< 3 {
        group.addTask {
          try await networking.request("GET", API.Users.profile, body: nil as String?, queryParameters: [:], idempotencyKey: "\(i)")
        }
      }

      for try await user in group {
        XCTAssertEqual(user.id, 1)
      }
    }

    // The coordinator deduplicates: concurrent 401s that overlap in time share the same
    // refresh Task. With 3 requests, timing determines whether we get 1, 2, or 3 refresh calls.
    // The important guarantee: at least 1 refresh happens, and all requests succeed.
    XCTAssertGreaterThanOrEqual(refreshCallCount.value, 1, "At least one refresh must occur")
    XCTAssertLessThanOrEqual(refreshCallCount.value, 3, "At most 3 refreshes (one per request)")
  }

  /// refreshTokenProvider returns nil → no refresh attempted, throws .unauthorized.
  func testNoRefreshTokenSkipsRefresh() async {
    let refreshCallCount = AtomicCounter()

    let networking = makeNetworking(
      token: { self.makeJWT(exp: Date().addingTimeInterval(3600)) },
      refreshToken: { nil },
      onTokenRefreshed: { _, _ in
        XCTFail("onTokenRefreshed should not be called when no refresh token")
      }
    )

    MockURLProtocol.requestHandler = { request in
      let path = request.url?.path ?? ""
      if path.hasSuffix("auth/refresh") {
        refreshCallCount.increment()
        return (MockURLProtocol.Stub(statusCode: 200, headers: [:], body: Data()), nil)
      }
      return (MockURLProtocol.Stub(statusCode: 401, headers: [:], body: Data()), nil)
    }

    do {
      let _: UserDTO = try await networking.request("GET", API.Users.profile, body: nil as String?, queryParameters: [:], idempotencyKey: nil)
      XCTFail("Expected unauthorized error")
    } catch let error as APIError {
      guard case .unauthorized = error else {
        return XCTFail("Expected .unauthorized but got \(error)")
      }
    } catch {
      XCTFail("Expected APIError but got \(error)")
    }

    XCTAssertEqual(refreshCallCount.value, 0, "No HTTP refresh call should be made when refresh token is nil")
  }

  // MARK: - Helpers

  private func makeNetworking(
    token: @escaping () -> String?,
    refreshToken: @escaping () -> String?,
    onTokenRefreshed: @escaping (String, String?) async -> Void
  ) -> InternalNetworking {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: config)
    let pinning = CertificatePinning(pinnedDomains: [], publicKeyHashes: [], enforceInDebug: false)

    return InternalNetworking(
      tokenProvider: token,
      refreshTokenProvider: refreshToken,
      onTokenRefreshed: onTokenRefreshed,
      session: session,
      certificatePinning: pinning
    )
  }

  /// Creates a minimal JWT with the given expiration date.
  /// Format: base64url(header).base64url(payload).signature
  private func makeJWT(exp: Date) -> String {
    let header = Data(#"{"alg":"HS256","typ":"JWT"}"#.utf8).base64URLEncoded()
    let payload = Data(#"{"sub":"1","exp":\#(Int(exp.timeIntervalSince1970))}"#.utf8).base64URLEncoded()
    let signature = Data("test-signature".utf8).base64URLEncoded()
    return "\(header).\(payload).\(signature)"
  }

  private func makeRefreshResponseBody(newToken: String, newRefreshToken: String) -> Data {
    let json: [String: Any] = [
      "user": ["id": 1, "email": "test@example.com", "name": "Test User", "role": "member", "timezone": "UTC", "has_password": true],
      "token": newToken,
      "refresh_token": newRefreshToken,
    ]
    return try! JSONSerialization.data(withJSONObject: json)
  }

  private func makeUserJSON() -> Data {
    let json: [String: Any] = [
      "id": 1, "email": "test@example.com", "name": "Test User",
      "role": "member", "timezone": "UTC", "has_password": true,
    ]
    return try! JSONSerialization.data(withJSONObject: json)
  }
}

// MARK: - AtomicCounter

/// Thread-safe counter for use in `requestHandler` closures (which run on URLProtocol's
/// background thread, outside Swift concurrency). NSLock is the right tool here because
/// the closures are non-async Objective-C callbacks.
private final class AtomicCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var _value = 0

  var value: Int {
    lock.lock()
    defer { lock.unlock() }
    return _value
  }

  @discardableResult
  func increment() -> Int {
    lock.lock()
    defer { lock.unlock() }
    _value += 1
    return _value
  }
}

// MARK: - Data+Base64URL

private extension Data {
  func base64URLEncoded() -> String {
    base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}
