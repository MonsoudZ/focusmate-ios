import Foundation
import Security

final class KeychainManager {
  static let shared = KeychainManager()
  private init() {}

  private let service = "com.focusmate.app"
  private let tokenKey = "jwt_token"

  func save(token: String) {
    let data = token.data(using: .utf8)!

    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: self.service,
      kSecAttrAccount as String: self.tokenKey,
      kSecValueData as String: data,
    ]

    // Delete existing item first
    SecItemDelete(query as CFDictionary)

    // Add new item
    let status = SecItemAdd(query as CFDictionary, nil)
    if status != errSecSuccess {
      print("❌ KeychainManager: Failed to save token: \(status)")
    } else {
      print("✅ KeychainManager: Token saved successfully")
    }
  }

  func load() -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: self.service,
      kSecAttrAccount as String: self.tokenKey,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    if status == errSecSuccess,
       let data = result as? Data,
       let token = String(data: data, encoding: .utf8)
    {
      print("✅ KeychainManager: Token loaded successfully")
      return token
    } else {
      print("⚠️ KeychainManager: No token found or error: \(status)")
      return nil
    }
  }

  func clear() {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: self.service,
      kSecAttrAccount as String: self.tokenKey,
    ]

    let status = SecItemDelete(query as CFDictionary)
    if status == errSecSuccess {
      print("✅ KeychainManager: Token cleared successfully")
    } else {
      print("⚠️ KeychainManager: Failed to clear token: \(status)")
    }
  }
}
