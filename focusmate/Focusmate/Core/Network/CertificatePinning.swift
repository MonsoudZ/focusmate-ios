import Foundation
import Security
import CommonCrypto

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
        guard pinnedDomains.contains(domain) else {
            Logger.debug("Domain '\(domain)' not in pinned list, allowing", category: .api)
            return true
        }

        Logger.debug("Validating certificate for domain '\(domain)'", category: .api)

        guard let certificateChain = getCertificateChain(from: serverTrust) else {
            Logger.error("Failed to get certificate chain", category: .api)
            return !enforcePinning
        }

        let serverPublicKeyHashes = certificateChain.compactMap { publicKeyHash(for: $0) }

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

    private func getCertificateChain(from serverTrust: SecTrust) -> [SecCertificate]? {
        var certificateChain: [SecCertificate] = []

        if #available(iOS 15.0, *) {
            guard let certificates = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
                return nil
            }
            certificateChain = certificates
        } else {
            let certificateCount = SecTrustGetCertificateCount(serverTrust)
            for index in 0..<certificateCount {
                if let certificate = SecTrustGetCertificateAtIndex(serverTrust, index) {
                    certificateChain.append(certificate)
                }
            }
        }

        return certificateChain.isEmpty ? nil : certificateChain
    }

    private func publicKeyHash(for certificate: SecCertificate) -> String? {
        guard let publicKey = SecCertificateCopyKey(certificate),
              let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            return nil
        }
        return sha256Hash(of: publicKeyData)
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

        if validateServerTrust(serverTrust, forDomain: domain) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            Logger.error("Cancelling connection to '\(domain)' due to certificate validation failure", category: .api)
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

struct CertificatePinningConfig {
    static let productionDomain = "focusmate-api-production.up.railway.app"

    // Certificate pinning disabled - using standard TLS validation
    // Enable later for high-security requirements by adding domain and hash
    static var pinnedDomains: Set<String> { [] }
    static var publicKeyHashes: Set<String> { [] }

    static func createPinning(enforceInDebug: Bool = false) -> CertificatePinning {
        CertificatePinning(
            pinnedDomains: pinnedDomains,
            publicKeyHashes: publicKeyHashes,
            enforceInDebug: enforceInDebug
        )
    }
}
