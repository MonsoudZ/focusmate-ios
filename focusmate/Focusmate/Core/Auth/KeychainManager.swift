import Foundation
import Security

final class KeychainManager: @unchecked Sendable {
  static let shared = KeychainManager()
  private init() {}

  private let service = "com.intentia.app"
  private let tokenKey = "jwt_token"
  private let refreshTokenKey = "refresh_token"

  @discardableResult
  func save(token: String) -> Bool {
    guard let data = token.data(using: .utf8) else {
      Logger.error("Failed to encode token to Data", category: .auth)
      return false
    }

    let searchQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: self.service,
      kSecAttrAccount as String: self.tokenKey,
    ]

    let updateAttributes: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]

    // Atomic update: SecItemUpdate replaces the value in-place without a
    // delete+add gap. If the item doesn't exist yet, fall back to add.
    let updateStatus = SecItemUpdate(searchQuery as CFDictionary, updateAttributes as CFDictionary)

    if updateStatus == errSecItemNotFound {
      var addQuery = searchQuery
      addQuery[kSecValueData as String] = data
      addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
      if addStatus != errSecSuccess {
        Logger.error("Failed to save token to keychain (status: \(addStatus))", category: .auth)
        return false
      } else {
        Logger.debug("Token saved to keychain successfully", category: .auth)
        return true
      }
    } else if updateStatus != errSecSuccess {
      Logger.error("Failed to update token in keychain (status: \(updateStatus))", category: .auth)
      return false
    } else {
      Logger.debug("Token updated in keychain successfully", category: .auth)
      return true
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

  // MARK: - Refresh Token

  @discardableResult
  func save(refreshToken: String) -> Bool {
    guard let data = refreshToken.data(using: .utf8) else {
      Logger.error("Failed to encode refresh token to Data", category: .auth)
      return false
    }

    let searchQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: self.service,
      kSecAttrAccount as String: self.refreshTokenKey,
    ]

    let updateAttributes: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]

    let updateStatus = SecItemUpdate(searchQuery as CFDictionary, updateAttributes as CFDictionary)

    if updateStatus == errSecItemNotFound {
      var addQuery = searchQuery
      addQuery[kSecValueData as String] = data
      addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
      if addStatus != errSecSuccess {
        Logger.error("Failed to save refresh token to keychain (status: \(addStatus))", category: .auth)
        return false
      } else {
        Logger.debug("Refresh token saved to keychain successfully", category: .auth)
        return true
      }
    } else if updateStatus != errSecSuccess {
      Logger.error("Failed to update refresh token in keychain (status: \(updateStatus))", category: .auth)
      return false
    } else {
      Logger.debug("Refresh token updated in keychain successfully", category: .auth)
      return true
    }
  }

  func loadRefreshToken() -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: self.service,
      kSecAttrAccount as String: self.refreshTokenKey,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    if status == errSecSuccess,
       let data = result as? Data,
       let token = String(data: data, encoding: .utf8)
    {
      return token
    } else {
      if status != errSecItemNotFound {
        Logger.warning("Failed to load refresh token from keychain (status: \(status))", category: .auth)
      }
      return nil
    }
  }

  func clearRefreshToken() {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: self.service,
      kSecAttrAccount as String: self.refreshTokenKey,
    ]

    let status = SecItemDelete(query as CFDictionary)
    if status != errSecSuccess && status != errSecItemNotFound {
      Logger.warning("Failed to clear refresh token from keychain (status: \(status))", category: .auth)
    }
  }
}
