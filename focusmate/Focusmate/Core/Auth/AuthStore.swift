import Combine
import Foundation

@MainActor
final class AuthStore: ObservableObject {
  @Published var jwt: String? {
    didSet {
      #if DEBUG
      print("🔑 JWT updated: \(self.jwt != nil ? "SET" : "CLEARED")")
      #endif
    }
  }

  @Published var currentUser: UserDTO? {
    didSet {
      #if DEBUG
      print("👤 Current user updated: \(self.currentUser?.email ?? "nil")")
      #endif
    }
  }

  @Published var isLoading = false
  @Published var error: String?

  private(set) lazy var api: APIClient = APIClient { [weak self] in self?.jwt }
  private let authSession = AuthSession()
  private let newAPIClient: NewAPIClient
  private let authAPI: AuthAPI

  init() {
    let loadedJWT = KeychainManager.shared.load()
    self.jwt = loadedJWT
    
    // Initialize new API layer
    self.newAPIClient = NewAPIClient(auth: authSession)
    self.authAPI = AuthAPI(api: newAPIClient, session: authSession)
    
    // Set token in auth session if we have one
    if let token = loadedJWT {
      Task {
        await authSession.set(token: token)
      }
    }
  }

  struct SignInReq: Encodable { let email: String; let password: String }
  struct SignInResp: Decodable {
    let token: String
    let user: UserDTO

    enum CodingKeys: String, CodingKey {
      case token, user
    }
  }

  struct RegisterReq: Encodable {
    let user: UserRegistrationData

    struct UserRegistrationData: Encodable {
      let email: String
      let password: String
      let password_confirmation: String
      let name: String
    }
  }

  struct RegisterResp: Decodable {
    let token: String
    let user: UserDTO

    enum CodingKeys: String, CodingKey {
      case token, user
    }
  }

  // Profile endpoint returns user directly (flat structure)
  // No need for ProfileResp wrapper

  func signIn(email: String, password: String) async {
    #if DEBUG
    print("🔄 AuthStore: Starting sign in for \(email)")
    #endif
    #if DEBUG
    print("🌐 API Base URL: \(API.base)")
    #endif
    self.isLoading = true; self.error = nil
    do {
      // Use new AuthAPI
      let user = try await authAPI.signIn(email: email, password: password)
      #if DEBUG
      print("✅ Sign in successful: user=\(user)")
      #endif

      // Get token from auth session
      let token = try await authSession.access()
      
      // Store token and user data
      self.jwt = token
      KeychainManager.shared.save(token: token)
      self.currentUser = user

      #if DEBUG
      print("🔑 AuthStore: JWT set to: \(self.jwt != nil ? "SET" : "NIL")")
      #endif
      #if DEBUG
      print("👤 AuthStore: Current user set to: \(self.currentUser?.email ?? "nil")")
      #endif

    } catch {
      #if DEBUG
      print("❌ Sign in failed: \(error)")
      #endif
      #if DEBUG
      print("🔍 Error details: \(String(describing: error))")
      #endif
      
      // Provide more user-friendly error messages
      let userFriendlyError: String
      if let appError = error as? AppError {
        switch appError {
        case .notFound:
          userFriendlyError = "Invalid email or password"
        case .network(let urlError):
          userFriendlyError = "Network error: \(urlError.localizedDescription)"
        case .server(let message):
          userFriendlyError = "Server error: \(message)"
        default:
          userFriendlyError = "Authentication failed: \(appError)"
        }
      } else {
        userFriendlyError = "Authentication failed: \(error.localizedDescription)"
      }
      
      self.error = userFriendlyError
      self.jwt = nil
      KeychainManager.shared.clear()
    }
    self.isLoading = false
  }

  func register(email: String, password: String, name: String) async {
    self.isLoading = true; self.error = nil
    do {
      // Use new AuthAPI
      let user = try await authAPI.signUp(name: name, email: email, password: password)
      #if DEBUG
      print("✅ Registration successful: user=\(user)")
      #endif

      // Get token from auth session
      let token = try await authSession.access()
      
      self.jwt = token
      KeychainManager.shared.save(token: token)
      self.currentUser = user
    } catch {
      #if DEBUG
      print("❌ Registration failed: \(error)")
      #endif
      self.error = "\(error)"; self.jwt = nil; KeychainManager.shared.clear()
    }
    self.isLoading = false
  }

  func loadProfile() async {
    // Skip if user is already loaded (from sign-in response)
    guard self.currentUser == nil else {
      #if DEBUG
      print("ℹ️ AuthStore: User already loaded, skipping profile fetch")
      #endif
      return
    }

    #if DEBUG
    print("🔄 AuthStore: Loading profile...")
    #endif
    do {
      // Profile endpoint returns user directly (flat structure)
      self.currentUser = try await self.api.request("GET", "profile", body: nil as String?) as UserDTO
      #if DEBUG
      print("✅ AuthStore: Profile loaded successfully: \(self.currentUser?.email ?? "nil")")
      #endif
    } catch {
      if case APIError.unauthorized = error {
        #if DEBUG
        print("🚪 AuthStore: 401 on profile, auto sign-out")
        #endif
        await self.signOut()
      } else if case APIError.badStatus(404, _, _) = error {
        #if DEBUG
        print("⚠️ AuthStore: Profile endpoint not available (404), this is OK if user was set during sign-in")
        #endif
      } else {
        #if DEBUG
        print("❌ AuthStore: Failed to load profile: \(error)")
        #endif
        self.error = "\(error)"
      }
    }
  }

  func signOut() async {
    #if DEBUG
    print("🔄 AuthStore: Signing out...")
    #endif
    _ = try? await self.api.request("DELETE", "auth/sign_out", body: nil as String?) as EmptyDecodable
    #if DEBUG
    print("✅ AuthStore: Sign out successful")
    #endif
    
    // Clear auth session
    await authSession.clear()
    
    self.jwt = nil; self.currentUser = nil; KeychainManager.shared.clear()
  }
}

struct EmptyDecodable: Decodable {}
