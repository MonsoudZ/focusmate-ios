import Foundation
import Combine

@MainActor
final class AuthStore: ObservableObject {
    @Published var jwt: String? { 
        didSet { 
            print("🔑 JWT updated: \(jwt != nil ? "SET" : "CLEARED")")
        } 
    }
    @Published var currentUser: UserDTO? { 
        didSet { 
            print("👤 Current user updated: \(currentUser?.email ?? "nil")")
        } 
    }
    @Published var isLoading = false
    @Published var error: String?

    private(set) lazy var api: APIClient = APIClient { [weak self] in self?.jwt }

    init() {
        let loadedJWT = KeychainManager.shared.load()
        self.jwt = loadedJWT
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
        print("🔄 AuthStore: Starting sign in for \(email)")
        isLoading = true; error = nil
        do {
            let resp: SignInResp = try await api.request("POST", "auth/sign_in", body: SignInReq(email: email, password: password))
            print("✅ Sign in successful: token=\(resp.token), user=\(resp.user)")
            
            // Store token and user data
            jwt = resp.token
            KeychainManager.shared.save(token: resp.token)
            currentUser = resp.user
            
            print("🔑 AuthStore: JWT set to: \(jwt != nil ? "SET" : "NIL")")
            print("👤 AuthStore: Current user set to: \(currentUser?.email ?? "nil")")
            
        } catch {
            print("❌ Sign in failed: \(error)")
            self.error = "\(error)"; jwt = nil; KeychainManager.shared.clear()
        }
        isLoading = false
    }

    func register(email: String, password: String, name: String) async {
        isLoading = true; error = nil
        do {
            let userData = RegisterReq.UserRegistrationData(
                email: email, 
                password: password, 
                password_confirmation: password, 
                name: name
            )
            let resp: RegisterResp = try await api.request("POST", "auth/sign_up", body: RegisterReq(user: userData))
            print("✅ Registration successful: token=\(resp.token), user=\(resp.user)")
            jwt = resp.token
            KeychainManager.shared.save(token: resp.token)
            currentUser = resp.user
        } catch {
            print("❌ Registration failed: \(error)")
            self.error = "\(error)"; jwt = nil; KeychainManager.shared.clear()
        }
        isLoading = false
    }

    func loadProfile() async {
        print("🔄 AuthStore: Loading profile...")
        do { 
            // Profile endpoint returns user directly (flat structure)
            currentUser = try await api.request("GET", "profile", body: nil as String?) as UserDTO
            print("✅ AuthStore: Profile loaded successfully: \(currentUser?.email ?? "nil")")
        }
        catch {
            if case APIError.unauthorized = error {
                print("🚪 AuthStore: 401 on profile, auto sign-out")
                await signOut()
            } else {
                print("❌ AuthStore: Failed to load profile: \(error)")
                self.error = "\(error)"
            }
        }
    }

    func signOut() async {
        print("🔄 AuthStore: Signing out...")
        _ = try? await api.request("DELETE", "auth/sign_out", body: nil as String?) as EmptyDecodable
        print("✅ AuthStore: Sign out successful")
        jwt = nil; currentUser = nil; KeychainManager.shared.clear()
    }
}

struct EmptyDecodable: Decodable {}
