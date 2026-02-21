import XCTest
import Security
import CryptoKit
@testable import focusmate

final class CertificatePinningTests: XCTestCase {

    // MARK: - Embedded Test Certificate

    /// A real self-signed X.509 certificate (CN=api.example.com) generated via openssl.
    /// SecTrustCreateWithCertificates requires at least one valid cert — raw byte
    /// hacks don't work because SecCertificateCreateWithData validates DER structure.
    // swiftlint:disable:next line_length
    private static let testCertBase64 = "MIIDFTCCAf2gAwIBAgIUP8gBHBiZRf+bdtRjWXq6byUWSukwDQYJKoZIhvcNAQELBQAwGjEYMBYGA1UEAwwPYXBpLmV4YW1wbGUuY29tMB4XDTI2MDIxODE1NTc1NVoXDTI3MDIxODE1NTc1NVowGjEYMBYGA1UEAwwPYXBpLmV4YW1wbGUuY29tMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAzZBo/Hd5B6dXVU+d3psQsxbw/WTRe/jlT0BwPPHyxbXCOZo5VoE/NC2diENKrxT/uyOciMRAsbDGsHlK18fs2k/skPNESTXCyvz76yqbg/028tsWyQ3pKpKr57fYLGxxhswnr5sL/55qJ5JDm3397EDGgOL40wimviNq4uLgv61IAnfQKDgbvTKlvCFzco9x9DUj6qiTL7STq/NcNd2LpWxMKUzsmC/Pb7Cw1NLMmNXOVczEvg9R+zhm0gIBb1l9PY8Wcmcs2KWzaA83mnHidM/cBtpnk98rj61EGDrzU7EF0yoUthux8eguIsx02HGos/JHTIQ6lSDQHjNeseoBvQIDAQABo1MwUTAdBgNVHQ4EFgQU8RJkIYxrh6c3UAuE651DqxNCTIkwHwYDVR0jBBgwFoAU8RJkIYxrh6c3UAuE651DqxNCTIkwDwYDVR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEAxBRv5W2XW5y5NGWEqj3RRIw8KUmQETdhsf8HClRz2KR/2zbNGd+TpuE30eHcHgsgi3sb0bvWIklCEVa92K2rhPQQgf6UVIxtqFB4jJ2LhbaI9S0oiX915opW0WkoVEjd6qL8IlDy5iDr4bveKoG4JjNjqtyPvyrJGtrKQwd3keYuAeOJyxfL4O4Bs2fGty4gGKw3NH7uJ8BxNh3CLjjGDb14dh9qe2COndaU33UK4rsWBJvy4BRm3V5hrQJovMqqGZIxljUWdhsHIycE602K4W2bkLwskgN539TEDU5CFtmLHNpSzRlhoFX9xEzh/ObltKmyx9XuEiF7jD5jedWv4Q=="

    /// Computed lazily by extracting the public key from the test cert using the same
    /// Security framework API that CertificatePinning uses (SecCertificateCopyKey →
    /// SecKeyCopyExternalRepresentation → SHA-256). This avoids format mismatches
    /// between openssl (SPKI DER) and SecKey (PKCS#1 raw key bytes).
    private static let testCertPublicKeyHash: String = {
        let certData = Data(base64Encoded: testCertBase64)!
        let cert = SecCertificateCreateWithData(nil, certData as CFData)!
        let publicKey = SecCertificateCopyKey(cert)!
        let keyData = SecKeyCopyExternalRepresentation(publicKey, nil)! as Data
        return SHA256.hash(data: keyData).map { String(format: "%02x", $0) }.joined()
    }()

    // MARK: - Domain Filtering

    func testNonPinnedDomainIsAllowedWithoutValidation() {
        let sut = CertificatePinning(
            pinnedDomains: ["api.example.com"],
            publicKeyHashes: ["abc123"],
            enforceInDebug: true
        )

        let trust = createTrustWithTestCert()
        let result = sut.validateServerTrust(trust, forDomain: "other.example.com")
        XCTAssertTrue(result, "Non-pinned domains should always be allowed")
    }

    // MARK: - Hash Matching

    func testPinnedDomainWithNoMatchingHashFails() {
        let sut = CertificatePinning(
            pinnedDomains: ["api.example.com"],
            publicKeyHashes: ["nonexistent_hash_that_will_never_match"],
            enforceInDebug: true
        )

        let trust = createTrustWithTestCert()
        let result = sut.validateServerTrust(trust, forDomain: "api.example.com")
        XCTAssertFalse(result, "Pinned domain with no matching hash should fail when enforced")
    }

    func testPinnedDomainWithNoMatchAllowedWhenNotEnforced() {
        let sut = CertificatePinning(
            pinnedDomains: ["api.example.com"],
            publicKeyHashes: ["nonexistent_hash_that_will_never_match"],
            enforceInDebug: false
        )

        let trust = createTrustWithTestCert()
        let result = sut.validateServerTrust(trust, forDomain: "api.example.com")
        XCTAssertTrue(result, "Pinned domain should be allowed in debug when not enforced")
    }

    func testPinnedDomainWithMatchingHashSucceeds() {
        let sut = CertificatePinning(
            pinnedDomains: ["api.example.com"],
            publicKeyHashes: [Self.testCertPublicKeyHash],
            enforceInDebug: true
        )

        let trust = createTrustWithTestCert()
        let result = sut.validateServerTrust(trust, forDomain: "api.example.com")
        XCTAssertTrue(result, "Pinned domain with matching hash should succeed")
    }

    func testMultipleHashesOneMatchingSuffices() {
        let sut = CertificatePinning(
            pinnedDomains: ["api.example.com"],
            publicKeyHashes: ["wrong_hash_1", Self.testCertPublicKeyHash, "wrong_hash_2"],
            enforceInDebug: true
        )

        let trust = createTrustWithTestCert()
        let result = sut.validateServerTrust(trust, forDomain: "api.example.com")
        XCTAssertTrue(result, "Should succeed when any hash in the set matches")
    }

    // MARK: - Edge Cases

    func testEmptyPinnedDomainsAllowsAllDomains() {
        // When pinnedDomains is empty, `pinnedDomains.contains(domain)` is always
        // false → the guard returns true (allow). This is a fail-open design: if
        // misconfigured with no domains, all traffic is allowed through unpinned.
        let sut = CertificatePinning(
            pinnedDomains: [],
            publicKeyHashes: ["abc123"],
            enforceInDebug: true
        )

        let trust = createTrustWithTestCert()
        XCTAssertTrue(
            sut.validateServerTrust(trust, forDomain: "api.example.com"),
            "Empty pinnedDomains should bypass validation for any domain"
        )
        XCTAssertTrue(
            sut.validateServerTrust(trust, forDomain: "evil.example.com"),
            "Empty pinnedDomains should bypass validation for any domain"
        )
    }

    func testMultiplePinnedDomainsOnlyMatchingDomainIsValidated() {
        // Mirrors production config: both prod + staging domains pinned.
        // Non-pinned domain bypasses; pinned domain with matching cert succeeds.
        let sut = CertificatePinning(
            pinnedDomains: ["api.example.com", "api.staging.example.com"],
            publicKeyHashes: [Self.testCertPublicKeyHash],
            enforceInDebug: true
        )

        let trust = createTrustWithTestCert()

        // Pinned domain with matching cert → success
        XCTAssertTrue(
            sut.validateServerTrust(trust, forDomain: "api.example.com"),
            "Pinned domain with matching hash should succeed"
        )

        // Non-pinned domain → bypass (no validation)
        XCTAssertTrue(
            sut.validateServerTrust(trust, forDomain: "cdn.example.com"),
            "Non-pinned domain should bypass validation entirely"
        )
    }

    // MARK: - Empty Chain Handling
    // getCertificateChain returns nil when chain is empty → validateServerTrust
    // returns !enforcePinning. We can't create a SecTrust with zero certs
    // (SecTrustCreateWithCertificates requires ≥1), but we CAN create a trust
    // whose cert has no extractable public key by using an EC cert that the
    // source's SecCertificateCopyKey returns nil for in some configurations.
    // For practical coverage, the "no matching hash" tests above exercise the
    // same enforced/non-enforced branching, just via the hash-mismatch path
    // instead of the nil-chain path. Both return !enforcePinning on failure.

    // MARK: - Config

    func testCertificatePinningConfigHasBothDomains() {
        let domains = CertificatePinningConfig.pinnedDomains
        XCTAssertTrue(domains.contains(CertificatePinningConfig.productionDomain))
        XCTAssertTrue(domains.contains(CertificatePinningConfig.stagingDomain))
        XCTAssertEqual(domains.count, 2)
    }

    func testCertificatePinningConfigHasTwoHashes() {
        // Dual-pin strategy: leaf + intermediate
        let hashes = CertificatePinningConfig.publicKeyHashes
        XCTAssertEqual(hashes.count, 2, "Should have exactly 2 hashes (leaf + intermediate)")
    }

    func testCreatePinningReturnsConfiguredInstance() {
        let pinning = CertificatePinningConfig.createPinning()

        // Verify it allows non-pinned domains
        let trust = createTrustWithTestCert()
        let result = pinning.validateServerTrust(trust, forDomain: "unrelated.example.com")
        XCTAssertTrue(result, "Factory-created pinning should allow non-pinned domains")
    }

    // MARK: - URLSession Delegate

    func testDelegatePerformsDefaultHandlingForNonServerTrustChallenge() {
        let sut = CertificatePinning(
            pinnedDomains: ["api.example.com"],
            publicKeyHashes: ["abc"],
            enforceInDebug: true
        )

        let protectionSpace = URLProtectionSpace(
            host: "api.example.com",
            port: 443,
            protocol: NSURLProtectionSpaceHTTPS,
            realm: nil,
            authenticationMethod: NSURLAuthenticationMethodHTTPBasic
        )
        let challenge = URLAuthenticationChallenge(
            protectionSpace: protectionSpace,
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: FakeChallengeSender()
        )

        let expectation = expectation(description: "Completion called")
        sut.urlSession(URLSession.shared, didReceive: challenge) { disposition, credential in
            XCTAssertEqual(disposition, .performDefaultHandling)
            XCTAssertNil(credential)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Helpers

    /// Creates a SecTrust containing the embedded self-signed test certificate.
    private func createTrustWithTestCert() -> SecTrust {
        let certData = Data(base64Encoded: Self.testCertBase64)!
        let cert = SecCertificateCreateWithData(nil, certData as CFData)!
        var trust: SecTrust?
        SecTrustCreateWithCertificates(cert, SecPolicyCreateSSL(true, nil), &trust)
        return trust!
    }
}

/// Minimal sender to satisfy URLAuthenticationChallenge init.
private final class FakeChallengeSender: NSObject, URLAuthenticationChallengeSender {
    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}
    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}
    func cancel(_ challenge: URLAuthenticationChallenge) {}
}
