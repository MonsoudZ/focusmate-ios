import CommonCrypto
import Foundation
import Security

final class CertificatePinning: NSObject {
  private let pinnedDomains: Set<String>
  private let pinnedPublicKeyHashes: Set<String>
  private let enforcePinning: Bool

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

  func validateServerTrust(_ serverTrust: SecTrust, forDomain domain: String) -> Bool {
    guard self.pinnedDomains.contains(domain) else {
      Logger.debug("Domain '\(domain)' not in pinned list, allowing", category: .api)
      return true
    }

    Logger.debug("Validating certificate for domain '\(domain)'", category: .api)

    guard let certificateChain = getCertificateChain(from: serverTrust) else {
      Logger.error("Failed to get certificate chain", category: .api)
      return !self.enforcePinning
    }

    let serverPublicKeyHashes = certificateChain.compactMap { self.publicKeyHash(for: $0) }

    let hasMatch = !serverPublicKeyHashes.filter { self.pinnedPublicKeyHashes.contains($0) }.isEmpty

    if hasMatch {
      Logger.info("Certificate validation successful", category: .api)
      return true
    } else {
      Logger.error("Certificate validation failed - no matching public key", category: .api)

      if !self.enforcePinning {
        Logger.warning("Pinning not enforced in DEBUG, allowing connection", category: .api)
        return true
      }

      return false
    }
  }

  private func getCertificateChain(from serverTrust: SecTrust) -> [SecCertificate]? {
    var certificateChain: [SecCertificate] = []

    if #available(iOS 15.0, *) {
      guard let certificates = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
        return nil
      }
      certificateChain = certificates
    } else {
      let certificateCount = SecTrustGetCertificateCount(serverTrust)
      for index in 0 ..< certificateCount {
        if let certificate = SecTrustGetCertificateAtIndex(serverTrust, index) {
          certificateChain.append(certificate)
        }
      }
    }

    return certificateChain.isEmpty ? nil : certificateChain
  }

  private func publicKeyHash(for certificate: SecCertificate) -> String? {
    guard let publicKey = SecCertificateCopyKey(certificate),
          let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?
    else {
      return nil
    }
    return self.sha256Hash(of: publicKeyData)
  }

  private func sha256Hash(of data: Data) -> String {
    var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    data.withUnsafeBytes {
      _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
    }
    return hash.map { String(format: "%02x", $0) }.joined()
  }
}

extension CertificatePinning: URLSessionDelegate {
  func urlSession(
    _ session: URLSession,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) {
    guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
      completionHandler(.performDefaultHandling, nil)
      return
    }

    guard let serverTrust = challenge.protectionSpace.serverTrust else {
      completionHandler(.cancelAuthenticationChallenge, nil)
      return
    }

    let domain = challenge.protectionSpace.host

    if self.validateServerTrust(serverTrust, forDomain: domain) {
      completionHandler(.useCredential, URLCredential(trust: serverTrust))
    } else {
      Logger.error("Cancelling connection to '\(domain)' due to certificate validation failure", category: .api)
      #if !DEBUG
        SentryService.shared.captureMessage("Certificate pinning failed for: \(domain)")
      #endif
      completionHandler(.cancelAuthenticationChallenge, nil)
    }
  }
}

enum CertificatePinningConfig {
  static let productionDomain = "focusmate-api-production.up.railway.app"
  static let stagingDomain = "focusmate-api-focusmate-api-staging.up.railway.app"

  static var pinnedDomains: Set<String> {
    [productionDomain, stagingDomain]
  }

  /// SHA-256 hashes of public keys in the TLS certificate chain.
  ///
  /// Both hashes are checked against every cert in the server's chain.
  /// If ANY cert matches ANY hash, the connection is allowed.
  ///
  /// - Leaf (*.up.railway.app): tight match while current. Rotates every
  ///   ~90 days via Let's Encrypt auto-renewal on Railway. When it rotates,
  ///   the intermediate hash still matches, so the app keeps working.
  ///
  /// - Intermediate (Let's Encrypt R13): stable for years. Survives leaf
  ///   rotation. Only requires an app update if LE retires R13 entirely
  ///   (pre-announced months in advance).
  ///
  /// To regenerate after a rotation:
  ///   echo | openssl s_client -connect <DOMAIN>:443 -servername <DOMAIN> 2>/dev/null \
  ///     | openssl x509 -pubkey -noout \
  ///     | openssl pkey -pubin -outform DER \
  ///     | openssl dgst -sha256 -hex
  static var publicKeyHashes: Set<String> {
    [
      // Leaf: *.up.railway.app (shared by production + staging)
      "bba75270b0ee1364eb024b3b72de070c17a45e8f5bc85112ea8029a96fe90234",
      // Intermediate: Let's Encrypt R13
      "025490860b498ab73c6a12f27a49ad5fe230fafe3ac8f6112c9b7d0aad46941d",
    ]
  }

  static func createPinning(enforceInDebug: Bool = false) -> CertificatePinning {
    if self.publicKeyHashes.isEmpty {
      // Fail-closed: empty hashes means no cert can match, so all connections
      // to pinned domains are rejected in Release. This is safer than the old
      // fail-open behavior (passing empty pinnedDomains, which disabled pinning
      // entirely). assertionFailure catches the misconfiguration in Debug.
      assertionFailure("CertificatePinning: publicKeyHashes is empty — pinning will reject all connections")
    }
    return CertificatePinning(
      pinnedDomains: self.pinnedDomains,
      publicKeyHashes: self.publicKeyHashes,
      enforceInDebug: enforceInDebug
    )
  }
}
