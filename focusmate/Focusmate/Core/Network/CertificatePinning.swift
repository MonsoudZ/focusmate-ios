import Foundation
import Security

/// SSL Certificate Pinning Implementation
/// Prevents Man-in-the-Middle (MITM) attacks by validating server certificates
/// against known good certificates bundled with the app.
final class CertificatePinning: NSObject {

  // MARK: - Configuration

  /// Domains that require certificate pinning
  private let pinnedDomains: Set<String>

  /// Public key hashes for pinned certificates (SHA256)
  /// These should be updated when certificates are rotated
  private let pinnedPublicKeyHashes: Set<String>

  /// Whether to enforce pinning or just log violations (useful for testing)
  private let enforcePinning: Bool

  // MARK: - Initialization

  init(
    pinnedDomains: Set<String>,
    publicKeyHashes: Set<String>,
    enforceInDebug: Bool = false
  ) {
    self.pinnedDomains = pinnedDomains
    self.pinnedPublicKeyHashes = publicKeyHashes

    #if DEBUG
    self.enforcePinning = enforceInDebug
    #else
    self.enforcePinning = true
    #endif
  }

  // MARK: - Public Interface

  /// Validates the server trust against pinned certificates
  /// - Parameters:
  ///   - serverTrust: The server trust to validate
  ///   - domain: The domain being connected to
  /// - Returns: Whether the server trust is valid
  func validateServerTrust(_ serverTrust: SecTrust, forDomain domain: String) -> Bool {
    // Only validate pinned domains
    guard pinnedDomains.contains(domain) else {
      Logger.debug("Domain '\(domain)' not in pinned list, allowing", category: .api)
      return true
    }

    Logger.debug("Validating certificate for domain '\(domain)'", category: .api)

    // Get the certificate chain
    guard let certificateChain = getCertificateChain(from: serverTrust) else {
      Logger.error("Failed to get certificate chain", category: .api)
      return !enforcePinning
    }

    // Extract public key hashes from the certificate chain
    let serverPublicKeyHashes = certificateChain.compactMap { certificate in
      return publicKeyHash(for: certificate)
    }

    Logger.debug("Server public key hashes: \(serverPublicKeyHashes)", category: .api)
    Logger.debug("Pinned public key hashes: \(pinnedPublicKeyHashes)", category: .api)

    // Check if any of the server's public keys match our pinned keys
    let hasMatch = !serverPublicKeyHashes.filter { pinnedPublicKeyHashes.contains($0) }.isEmpty

    if hasMatch {
      Logger.info("Certificate validation successful", category: .api)
      return true
    } else {
      Logger.error("Certificate validation failed - no matching public key", category: .api)

      if !enforcePinning {
        Logger.warning("Pinning not enforced in DEBUG, allowing connection", category: .api)
        return true
      }

      return false
    }
  }

  // MARK: - Private Helpers

  /// Extracts the certificate chain from a server trust
  private func getCertificateChain(from serverTrust: SecTrust) -> [SecCertificate]? {
    var certificateChain: [SecCertificate] = []

    // iOS 15+ API
    if #available(iOS 15.0, *) {
      guard let certificates = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
        return nil
      }
      certificateChain = certificates
    } else {
      // Fallback for older iOS versions
      let certificateCount = SecTrustGetCertificateCount(serverTrust)
      for index in 0..<certificateCount {
        if let certificate = SecTrustGetCertificateAtIndex(serverTrust, index) {
          certificateChain.append(certificate)
        }
      }
    }

    return certificateChain.isEmpty ? nil : certificateChain
  }

  /// Computes the SHA256 hash of a certificate's public key
  private func publicKeyHash(for certificate: SecCertificate) -> String? {
    guard let publicKey = SecCertificateCopyKey(certificate) else {
      return nil
    }

    guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
      return nil
    }

    return sha256Hash(of: publicKeyData)
  }

  /// Computes SHA256 hash of data
  private func sha256Hash(of data: Data) -> String {
    var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    data.withUnsafeBytes {
      _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
    }
    return hash.map { String(format: "%02x", $0) }.joined()
  }
}

// MARK: - CommonCrypto Import

import CommonCrypto

// MARK: - URLSessionDelegate Extension

extension CertificatePinning: URLSessionDelegate {
  func urlSession(
    _ session: URLSession,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) {
    // Only handle server trust challenges
    guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
      completionHandler(.performDefaultHandling, nil)
      return
    }

    guard let serverTrust = challenge.protectionSpace.serverTrust else {
      completionHandler(.cancelAuthenticationChallenge, nil)
      return
    }

    let domain = challenge.protectionSpace.host

    // Validate the server trust
    if validateServerTrust(serverTrust, forDomain: domain) {
      // Trust is valid, proceed with the connection
      let credential = URLCredential(trust: serverTrust)
      completionHandler(.useCredential, credential)
    } else {
      // Trust validation failed, cancel the connection
      Logger.error("Cancelling connection to '\(domain)' due to certificate validation failure", category: .api)
      completionHandler(.cancelAuthenticationChallenge, nil)
    }
  }
}

// MARK: - Certificate Pinning Configuration

/// Production configuration for certificate pinning
struct CertificatePinningConfig {

  /// Production API domain
  static let productionDomain = "api.focusmate.com"

  /// Staging API domain
  static let stagingDomain = "staging-api.focusmate.com"

  /// Get pinned domains based on environment
  static var pinnedDomains: Set<String> {
    #if DEBUG
    // In debug, we may use localhost or ngrok which can't be pinned
    return []
    #else
    return [productionDomain]
    #endif
  }

  /// Public key hashes for production certificates
  /// These are SHA256 hashes of the DER-encoded public keys
  ///
  /// To generate these:
  /// Run: ./scripts/generate_cert_hash.sh YOUR_DOMAIN
  /// Example: ./scripts/generate_cert_hash.sh api.focusmate.com
  ///
  /// The script will:
  /// 1. Fetch the certificate from your server
  /// 2. Extract and hash the public key
  /// 3. Generate Swift code for easy copy-paste
  /// 4. Save full certificate details to a file
  ///
  /// IMPORTANT: Include both current and backup certificates to prevent outages during rotation
  static var publicKeyHashes: Set<String> {
    #if DEBUG
    // Empty in debug to allow localhost/ngrok
    return []
    #elseif STAGING
    // ⚠️ WARNING: ngrok certificates change frequently!
    // Pinning is DISABLED in staging builds to prevent connection failures
    // when ngrok rotates certificates
    return []
    #else
    // ⚠️ PRODUCTION ONLY: Replace with your actual production domain hashes
    // DO NOT use the ngrok hash below in production!
    return [
      // ❌ NGROK HASH (FOR REFERENCE ONLY - expires Dec 29, 2025)
      // "6aac57a79c1be5f0764fe82e1271caf459e7e6f47f606fdb2a75c27da4e8287a",

      // ✅ TODO: Add your production domain certificate hash here
      // Example: api.focusmate.com
      // "YOUR_PRODUCTION_CERT_HASH_HERE",

      // ✅ TODO: Add backup certificate hash (for rotation)
      // "YOUR_BACKUP_CERT_HASH_HERE",

      // Note: Until production hashes are added, pinning is effectively disabled
      // (empty set allows all certificates)
    ]
    #endif
  }

  /// Create a configured CertificatePinning instance
  static func createPinning(enforceInDebug: Bool = false) -> CertificatePinning {
    return CertificatePinning(
      pinnedDomains: pinnedDomains,
      publicKeyHashes: publicKeyHashes,
      enforceInDebug: enforceInDebug
    )
  }
}
