import Foundation

enum LogRedactor {
    static func redact(_ input: String) -> String {
        var s = input

        s = s.replacingOccurrences(
            of: #"Bearer\s+[A-Za-z0-9\-\._~\+\/]+=*"#,
            with: "Bearer [REDACTED]",
            options: .regularExpression
        )

        s = s.replacingOccurrences(
            of: #""(token|jwt|access_token|refresh_token)"\s*:\s*"[^"]+""#,
            with: "\"$1\":\"[REDACTED]\"",
            options: .regularExpression
        )

        return s
    }
}
