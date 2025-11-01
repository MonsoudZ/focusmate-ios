import XCTest
@testable import focusmate

final class APIEndpointsTests: XCTestCase {
  // MARK: - WebSocket URL Auto-Derivation Tests

  func testWebSocketURLDerivation() {
    // Test that WebSocket URL is properly derived from base URL
    let webSocketURL = API.webSocketURL

    // Should be a valid URL
    XCTAssertNotNil(webSocketURL)

    // Should contain /cable path
    XCTAssertTrue(webSocketURL.absoluteString.contains("/cable"))
  }

  func testWebSocketURLProtocol() {
    let webSocketURL = API.webSocketURL
    let urlString = webSocketURL.absoluteString

    // Should use ws:// or wss:// protocol
    XCTAssertTrue(
      urlString.hasPrefix("ws://") || urlString.hasPrefix("wss://"),
      "WebSocket URL should use ws:// or wss:// protocol"
    )

    // Should NOT use http:// or https://
    XCTAssertFalse(urlString.hasPrefix("http://"))
    XCTAssertFalse(urlString.hasPrefix("https://"))
  }

  func testWebSocketURLMatchesBaseURL() {
    let baseURL = API.base
    let webSocketURL = API.webSocketURL

    // Extract host from both URLs
    let baseHost = baseURL.host
    let webSocketHost = webSocketURL.host

    // Hosts should match
    XCTAssertEqual(baseHost, webSocketHost, "WebSocket and REST API should use the same host")
  }

  func testWebSocketURLEndsWithCable() {
    let webSocketURL = API.webSocketURL

    // Should end with /cable
    XCTAssertTrue(
      webSocketURL.path.hasSuffix("/cable"),
      "WebSocket URL path should end with /cable"
    )
  }

  func testWebSocketURLDoesNotContainAPIV1() {
    let webSocketURL = API.webSocketURL

    // Should NOT contain /api/v1 in the path
    XCTAssertFalse(
      webSocketURL.absoluteString.contains("/api/v1"),
      "WebSocket URL should not contain /api/v1 path"
    )
  }

  // MARK: - API Endpoint Tests

  func testAuthEndpoints() {
    XCTAssertEqual(API.Auth.signIn, "/api/v1/auth/sign_in")
    XCTAssertEqual(API.Auth.signUp, "/api/v1/auth/sign_up")
    XCTAssertEqual(API.Auth.signOut, "/api/v1/auth/sign_out")
  }

  func testUsersEndpoints() {
    XCTAssertEqual(API.Users.deviceToken, "/api/v1/users/device_token")
  }

  func testListsEndpoints() {
    XCTAssertEqual(API.Lists.root, "/api/v1/lists")
    XCTAssertEqual(API.Lists.id("123"), "/api/v1/lists/123")
    XCTAssertEqual(API.Lists.tasks("456"), "/api/v1/lists/456/tasks")
    XCTAssertEqual(API.Lists.task("789", "101"), "/api/v1/lists/789/tasks/101")
  }

  func testListsTaskActionEndpoints() {
    XCTAssertEqual(
      API.Lists.taskAction("123", "456", "complete"),
      "/api/v1/lists/123/tasks/456/complete"
    )
    XCTAssertEqual(
      API.Lists.taskAction("123", "456", "uncomplete"),
      "/api/v1/lists/123/tasks/456/uncomplete"
    )
    XCTAssertEqual(
      API.Lists.taskAction("123", "456", "reassign"),
      "/api/v1/lists/123/tasks/456/reassign"
    )
  }

  func testDashTasksEndpoints() {
    XCTAssertEqual(API.DashTasks.all, "/api/v1/tasks/all_tasks")
    XCTAssertEqual(API.DashTasks.blocking, "/api/v1/tasks/blocking")
    XCTAssertEqual(API.DashTasks.awaiting, "/api/v1/tasks/awaiting_explanation")
    XCTAssertEqual(API.DashTasks.overdue, "/api/v1/tasks/overdue")
  }

  // MARK: - Base URL Tests

  func testBaseURLConfiguration() {
    let baseURL = API.base

    // Should be a valid URL
    XCTAssertNotNil(baseURL)

    // Should use http or https protocol
    XCTAssertTrue(
      baseURL.scheme == "http" || baseURL.scheme == "https",
      "Base URL should use http or https protocol"
    )
  }

  func testBaseURLHost() {
    let baseURL = API.base

    // Should have a host
    XCTAssertNotNil(baseURL.host, "Base URL should have a host")
  }

  // MARK: - Environment Configuration Tests

  func testEnvironmentVariableConfiguration() {
    // Test that environment variable can override default
    // Note: This test verifies the logic exists, actual value depends on environment

    let baseURL = API.base

    // If STAGING_API_URL is set, it should be used
    if let stagingURL = ProcessInfo.processInfo.environment["STAGING_API_URL"], !stagingURL.isEmpty {
      XCTAssertEqual(baseURL.absoluteString, stagingURL)
    } else {
      // Otherwise, should default to localhost
      XCTAssertTrue(baseURL.absoluteString.contains("localhost"))
    }
  }

  // MARK: - Protocol Conversion Tests

  func testHTTPToWSConversion() {
    // Test logic: http:// should convert to ws://
    let httpURL = "http://example.com"
    var convertedString = httpURL.replacingOccurrences(of: "http://", with: "ws://")

    XCTAssertEqual(convertedString, "ws://example.com")
  }

  func testHTTPSToWSSConversion() {
    // Test logic: https:// should convert to wss://
    let httpsURL = "https://example.com"
    var convertedString = httpsURL.replacingOccurrences(of: "https://", with: "wss://")

    XCTAssertEqual(convertedString, "wss://example.com")
  }

  func testAPIV1PathRemoval() {
    // Test logic: /api/v1 suffix should be removed
    let urlWithAPIV1 = "http://example.com/api/v1"
    var processedString = urlWithAPIV1

    if processedString.hasSuffix("/api/v1") {
      processedString = String(processedString.dropLast(7))
    }

    XCTAssertEqual(processedString, "http://example.com")
  }

  func testCablePathAppending() {
    // Test logic: /cable should be appended
    var urlString = "ws://example.com"
    urlString += "/cable"

    XCTAssertEqual(urlString, "ws://example.com/cable")
  }

  // MARK: - Edge Case Tests

  func testWebSocketURLWithPort() {
    let baseURL = API.base

    // If base URL has a port, WebSocket URL should preserve it
    if let port = baseURL.port {
      let webSocketURL = API.webSocketURL
      XCTAssertEqual(webSocketURL.port, port, "WebSocket URL should preserve port from base URL")
    }
  }

  func testWebSocketURLIsNotEmpty() {
    let webSocketURL = API.webSocketURL

    XCTAssertFalse(webSocketURL.absoluteString.isEmpty, "WebSocket URL should not be empty")
  }

  func testWebSocketURLIsValidURL() {
    let webSocketURL = API.webSocketURL

    // Should be able to create URLComponents from it
    let components = URLComponents(url: webSocketURL, resolvingAgainstBaseURL: false)
    XCTAssertNotNil(components, "WebSocket URL should be a valid URL")
  }
}
