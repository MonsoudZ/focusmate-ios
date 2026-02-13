import Foundation

extension APIError {
    /// Returns true for errors that indicate the credentials are invalid (not transient).
    /// Network errors, timeouts, and server errors should NOT destroy an existing session.
    static func isCredentialError(_ error: Error) -> Bool {
        if let apiError = error as? APIError {
            switch apiError {
            case .unauthorized:
                return true
            case .badStatus(let status, _, _) where status == 401 || status == 422:
                return true
            case .validation:
                return true
            default:
                return false
            }
        }
        if let focusmateError = error as? FocusmateError {
            switch focusmateError {
            case .unauthorized, .badRequest, .validation:
                return true
            default:
                return false
            }
        }
        return false
    }
}
