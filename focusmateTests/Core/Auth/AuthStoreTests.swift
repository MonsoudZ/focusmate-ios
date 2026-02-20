@testable import focusmate
import XCTest

final class AuthStoreTests: XCTestCase {
  // MARK: - Fakes

  private final class FakeKeychain: KeychainManaging {
    var token: String?
    var refreshToken: String?
    @discardableResult func save(token: String) -> Bool {
      self.token = token; return true
    }

    func load() -> String? {
      self.token
    }

    func clear() {
      self.token = nil
    }

    @discardableResult func save(refreshToken: String) -> Bool {
      self.refreshToken = refreshToken; return true
    }

    func loadRefreshToken() -> String? {
      self.refreshToken
    }

    func clearRefreshToken() {
      self.refreshToken = nil
    }
  }

  private final class MockNetworking: NetworkingProtocol {
    enum Mode {
      case successUser(UserDTO)
      case failure(Error)
    }

    var mode: Mode

    init(mode: Mode) {
      self.mode = mode
    }

    func request<T: Decodable>(
      _ method: String,
      _ path: String,
      body: (some Encodable)?,
      queryParameters: [String: String],
      idempotencyKey: String?
    ) async throws -> T {
      // Only handle the profile request in these tests.
      if method == "GET", path == API.Users.profile {
        switch self.mode {
        case let .successUser(user):
          // AuthStore.validateSession() expects UserResponse, not raw UserDTO.
          // Swift 5.10 strictly rejects UserDTO as? UserResponse; Swift 6 is lenient.
          let response = UserResponse(user: user)
          guard let typed = response as? T else { throw APIError.decoding }
          return typed
        case let .failure(error):
          throw error
        }
      }

      // If AuthStore calls anything else unexpectedly, fail loudly.
      throw APIError.badStatus(500, "Unexpected request: \(method) \(path)", nil)
    }

  }

  // MARK: - Tests

  func testInitLoadsJwtFromKeychainWithoutAutoValidate() async {
    let keychain = FakeKeychain()
    keychain.token = "jwt-123"

    let store = await MainActor.run {
      AuthStore(
        keychain: keychain,
        networking: nil,
        autoValidateOnInit: false,
        eventBus: AuthEventBus(),
        escalationService: EscalationService(screenTimeService: MockScreenTimeService())
      )
    }

    let jwt = await MainActor.run { store.jwt }
    XCTAssertEqual(jwt, "jwt-123")
  }

  func testValidateSessionSuccessSetsCurrentUserAndKeepsJwt() async {
    let keychain = FakeKeychain()
    keychain.token = "jwt-123"

    let user = UserDTO(
      id: 1,
      email: "test@example.com",
      name: "Test User",
      role: "user",
      timezone: "America/New_York",
      hasPassword: true
    )

    let networking = MockNetworking(mode: .successUser(user))

    let store = await MainActor.run {
      AuthStore(
        keychain: keychain,
        networking: networking,
        autoValidateOnInit: false,
        eventBus: AuthEventBus(),
        escalationService: EscalationService(screenTimeService: MockScreenTimeService())
      )
    }

    await MainActor.run { store.jwt = "jwt-123" }
    await store.validateSession()

    let currentUser = await MainActor.run { store.currentUser }
    let jwt = await MainActor.run { store.jwt }

    XCTAssertEqual(currentUser, user)
    XCTAssertEqual(jwt, "jwt-123")
    XCTAssertEqual(keychain.token, "jwt-123") // still there
  }

  func testValidateSessionFailureClearsJwtUserAndKeychain() async {
    let keychain = FakeKeychain()
    keychain.token = "jwt-123"

    let networking = MockNetworking(mode: .failure(APIError.unauthorized(nil)))

    let store = await MainActor.run {
      AuthStore(
        keychain: keychain,
        networking: networking,
        autoValidateOnInit: false,
        eventBus: AuthEventBus(),
        escalationService: EscalationService(screenTimeService: MockScreenTimeService())
      )
    }

    await MainActor.run {
      store.jwt = "jwt-123"
      store.currentUser = UserDTO(
        id: 1,
        email: "test@example.com",
        name: "Test User",
        role: "user",
        timezone: "America/New_York",
        hasPassword: true
      )
    }

    await store.validateSession()

    let jwt = await MainActor.run { store.jwt }
    let currentUser = await MainActor.run { store.currentUser }

    XCTAssertNil(jwt)
    XCTAssertNil(currentUser)
    XCTAssertNil(keychain.token)
  }
}
