import XCTest
@testable import focusmate

final class JWTExpiryTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a JWT with the given payload claims. No signature validation
    /// happens in JWTExpiry, so the signature segment can be anything.
    private func makeJWT(claims: [String: Any]) -> String {
        let header = #"{"alg":"HS256","typ":"JWT"}"#
        let payload = try! JSONSerialization.data(withJSONObject: claims)

        func base64url(_ data: Data) -> String {
            data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }

        let headerB64 = base64url(Data(header.utf8))
        let payloadB64 = base64url(payload)
        return "\(headerB64).\(payloadB64).fakesignature"
    }

    // MARK: - expirationDate

    func testExpirationDateParsesValidJWT() throws {
        let expTimestamp: TimeInterval = 1_700_000_000 // 2023-11-14T22:13:20Z
        let jwt = makeJWT(claims: ["exp": expTimestamp, "sub": "user123"])

        let result = JWTExpiry.expirationDate(from: jwt)

        let resultDate = try XCTUnwrap(result)
        XCTAssertEqual(resultDate.timeIntervalSince1970, expTimestamp, accuracy: 0.001)
    }

    func testExpirationDateReturnsNilForMalformedJWT() {
        // Empty string
        XCTAssertNil(JWTExpiry.expirationDate(from: ""))
        // Only one segment
        XCTAssertNil(JWTExpiry.expirationDate(from: "abc"))
        // Two segments
        XCTAssertNil(JWTExpiry.expirationDate(from: "abc.def"))
        // Non-base64 payload
        XCTAssertNil(JWTExpiry.expirationDate(from: "abc.!!!.def"))
    }

    func testExpirationDateReturnsNilWhenNoExpClaim() {
        let jwt = makeJWT(claims: ["sub": "user123", "iat": 1_700_000_000])

        XCTAssertNil(JWTExpiry.expirationDate(from: jwt))
    }

    // MARK: - isExpiringSoon

    func testIsExpiringSoonReturnsTrueWhenExpired() {
        let pastExp = Date().addingTimeInterval(-60).timeIntervalSince1970
        let jwt = makeJWT(claims: ["exp": pastExp])

        XCTAssertTrue(JWTExpiry.isExpiringSoon(jwt, buffer: 300))
    }

    func testIsExpiringSoonReturnsTrueWithinBuffer() {
        // Expires in 2 minutes, buffer is 5 minutes → should be "expiring soon"
        let soonExp = Date().addingTimeInterval(120).timeIntervalSince1970
        let jwt = makeJWT(claims: ["exp": soonExp])

        XCTAssertTrue(JWTExpiry.isExpiringSoon(jwt, buffer: 300))
    }

    func testIsExpiringSoonReturnsFalseOutsideBuffer() {
        // Expires in 10 minutes, buffer is 5 minutes → not expiring soon
        let laterExp = Date().addingTimeInterval(600).timeIntervalSince1970
        let jwt = makeJWT(claims: ["exp": laterExp])

        XCTAssertFalse(JWTExpiry.isExpiringSoon(jwt, buffer: 300))
    }

    func testIsExpiringSoonReturnsFalseForUnparsableJWT() {
        // Fail-safe: unparseable JWT should NOT trigger proactive refresh
        XCTAssertFalse(JWTExpiry.isExpiringSoon("not-a-jwt", buffer: 300))
        XCTAssertFalse(JWTExpiry.isExpiringSoon("", buffer: 300))
    }
}
