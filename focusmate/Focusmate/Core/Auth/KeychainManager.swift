import Foundation
import Security

final class KeychainManager {
  static let shared = KeychainManager()
  private init() {}

  private let service = "com.intentia.app"
  private let tokenKey = "jwt_token"

  func save(token: String) {
    let data = token.data(using: .utf8)!

    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: self.service,
      kSecAttrAccount as String: self.tokenKey,
      kSecValueData as String: data,
      // Security: Only accessible after first unlock, never backed up to iCloud
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]

    // Delete existing item first
    SecItemDelete(query as CFDictionary)

    // Add new item
    let status = SecItemAdd(query as CFDictionary, nil)
    if status != errSecSuccess {
      Logger.error("Failed to save token to keychain (status: \(status))", category: .auth)
    } else {
      Logger.debug("Token saved to keychain successfully", category: .auth)
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
      Logger.debug("Token loaded from keychain successfully", category: .auth)
      return token
    } else {
      if status != errSecItemNotFound {
        Logger.warning("Failed to load token from keychain (status: \(status))", category: .auth)
      }
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
    if status == errSecSuccess || status == errSecItemNotFound {
      Logger.debug("Token cleared from keychain successfully", category: .auth)
    } else {
      Logger.warning("Failed to clear token from keychain (status: \(status))", category: .auth)
    }
  }
}
