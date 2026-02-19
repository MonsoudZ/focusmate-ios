import Foundation

/// Minimal JWT expiration parser for proactive token refresh.
///
/// **Why this exists:** JWTs are self-describing — the `exp` claim in the payload
/// tells us exactly when the token becomes invalid. Without parsing this, the system
/// is purely reactive: every request after token expiry triggers a 401 → refresh → retry
/// chain (two sequential round trips, 200-400ms). By reading `exp`, we can refresh
/// *before* expiry, eliminating the 401 round trip entirely.
///
/// **What this doesn't do:** No signature validation. That's the server's job.
/// We're a consumer optimizing for latency, not a verifier asserting authenticity.
/// The worst case if `exp` is spoofed is that we skip proactive refresh and fall
/// back to the reactive 401 path — which is exactly what we had before.
enum JWTExpiry {
  /// Extracts the expiration date from a JWT's `exp` claim.
  ///
  /// JWT structure: `<header>.<payload>.<signature>`, each segment base64url-encoded.
  /// We decode segment [1] (payload), parse as JSON, and read `exp` (Unix timestamp).
  ///
  /// - Returns: The expiration `Date`, or `nil` if the JWT is malformed or has no `exp`.
  static func expirationDate(from jwt: String) -> Date? {
    let segments = jwt.split(separator: ".")
    guard segments.count == 3 else { return nil }

    let payloadSegment = String(segments[1])

    // Base64url → Base64: replace URL-safe chars and pad to multiple of 4.
    var base64 = payloadSegment
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    let remainder = base64.count % 4
    if remainder != 0 {
      base64.append(contentsOf: String(repeating: "=", count: 4 - remainder))
    }

    guard let data = Data(base64Encoded: base64) else { return nil }

    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let exp = json["exp"] as? TimeInterval
    else { return nil }

    return Date(timeIntervalSince1970: exp)
  }

  /// Returns `true` if the JWT is expired or will expire within `buffer` seconds.
  ///
  /// **Fail-safe:** Returns `false` on parse failure. This means an unparseable JWT
  /// won't trigger a proactive refresh — we fall back to the reactive 401 path.
  /// This is intentional: false positives (unnecessary refreshes) waste a network call;
  /// false negatives (missed proactive refresh) just use the existing 401 path.
  static func isExpiringSoon(_ jwt: String, buffer: TimeInterval = 300) -> Bool {
    guard let expiry = expirationDate(from: jwt) else { return false }
    return expiry.timeIntervalSinceNow <= buffer
  }
}
