import Foundation

/// Unified error type for the Focusmate app with user-friendly messaging.
enum FocusmateError: LocalizedError, Equatable {
    case network(Error)
    case unauthorized(String?)
    case badRequest(String, String?)
    case notFound(String?)
    case serverError(Int, String?, String?)
    case decoding(String?)
    case validation([String: [String]], String?)
    case rateLimited(Int, String?)
    case timeout
    case noInternetConnection
    case custom(String, String?)

    // MARK: - Error Code

    var code: String {
        switch self {
        case .network:
            return "NETWORK_ERROR"
        case .unauthorized:
            return "UNAUTHORIZED"
        case .badRequest:
            return "BAD_REQUEST"
        case .notFound:
            return "NOT_FOUND"
        case let .serverError(code, _, _):
            return "SERVER_ERROR_\(code)"
        case .decoding:
            return "DECODING_ERROR"
        case .validation:
            return "VALIDATION_ERROR"
        case .rateLimited:
            return "RATE_LIMITED"
        case .timeout:
            return "TIMEOUT"
        case .noInternetConnection:
            return "NO_INTERNET"
        case let .custom(code, _):
            return code
        }
    }

    // MARK: - User-Friendly Message

    var message: String {
        switch self {
        case let .network(error):
            return "We're having trouble connecting. \(error.localizedDescription)"
        case let .unauthorized(message):
            return message ?? "Your session has expired. Please sign in again to continue."
        case let .badRequest(message, _):
            return message.isEmpty ? "There was a problem with your request." : message
        case let .notFound(message):
            return message ?? "We couldn't find what you're looking for. It may have been moved or deleted."
        case let .serverError(code, message, _):
            if code >= 500 {
                return message ?? "Our servers are experiencing issues. We're working on it! Please try again shortly."
            }
            return message ?? "Something went wrong on our end."
        case let .decoding(message):
            return message ?? "We received an unexpected response. Please try again."
        case let .validation(errors, customMessage):
            if let customMessage = customMessage, !customMessage.isEmpty {
                return customMessage
            }
            let errorMessages = errors.flatMap(\.value).joined(separator: "\n• ")
            return "Please fix the following:\n• \(errorMessages)"
        case let .rateLimited(seconds, message):
            if let message = message, !message.isEmpty {
                return message
            }
            if seconds > 60 {
                let minutes = seconds / 60
                return "You've made too many requests. Please wait \(minutes) minute\(minutes > 1 ? "s" : "") before trying again."
            }
            return "You've made too many requests. Please wait \(seconds) seconds before trying again."
        case .timeout:
            return "The request is taking longer than expected. Please check your connection and try again."
        case .noInternetConnection:
            return "You're offline. Please check your internet connection and try again."
        case let .custom(_, message):
            return message ?? "Something unexpected happened. Please try again."
        }
    }

    // MARK: - User-Friendly Title

    var title: String {
        switch self {
        case .network:
            return "Connection Problem"
        case .unauthorized:
            return "Sign In Required"
        case .badRequest:
            return "Invalid Request"
        case .notFound:
            return "Not Found"
        case .serverError:
            return "Server Error"
        case .decoding:
            return "Data Error"
        case .validation:
            return "Validation Error"
        case .rateLimited:
            return "Too Many Requests"
        case .timeout:
            return "Timeout"
        case .noInternetConnection:
            return "No Connection"
        case .custom:
            return "Error"
        }
    }

    // MARK: - Suggested Action

    var suggestedAction: String? {
        switch self {
        case .network, .timeout:
            return "Check your internet connection and try again."
        case .unauthorized:
            return "Sign in to continue using the app."
        case .noInternetConnection:
            return "Connect to the internet to sync your data."
        case .serverError:
            return "We're working on fixing this. Please try again in a few minutes."
        case .rateLimited:
            return "Take a short break and try again in a moment."
        default:
            return nil
        }
    }

    // MARK: - Retry Properties

    var isRateLimited: Bool {
        if case .rateLimited = self { return true }
        return false
    }

    var isRetryable: Bool {
        switch self {
        case .network, .timeout, .rateLimited, .serverError:
            return true
        case .unauthorized, .badRequest, .notFound, .decoding, .validation, .noInternetConnection, .custom:
            return false
        }
    }

    var retryAfterSeconds: Int? {
        switch self {
        case let .rateLimited(seconds, _):
            return seconds
        default:
            return nil
        }
    }

    // MARK: - LocalizedError

    var errorDescription: String? {
        return message
    }

    // MARK: - Equatable

    static func == (lhs: FocusmateError, rhs: FocusmateError) -> Bool {
        switch (lhs, rhs) {
        case let (.network(l), .network(r)):
            return l.localizedDescription == r.localizedDescription
        case let (.unauthorized(l), .unauthorized(r)):
            return l == r
        case let (.badRequest(lMsg, lCtx), .badRequest(rMsg, rCtx)):
            return lMsg == rMsg && lCtx == rCtx
        case let (.notFound(l), .notFound(r)):
            return l == r
        case let (.serverError(lCode, lMsg, lCtx), .serverError(rCode, rMsg, rCtx)):
            return lCode == rCode && lMsg == rMsg && lCtx == rCtx
        case let (.decoding(l), .decoding(r)):
            return l == r
        case let (.validation(lFields, lMsg), .validation(rFields, rMsg)):
            return lFields == rFields && lMsg == rMsg
        case let (.rateLimited(lSec, lMsg), .rateLimited(rSec, rMsg)):
            return lSec == rSec && lMsg == rMsg
        case (.timeout, .timeout):
            return true
        case (.noInternetConnection, .noInternetConnection):
            return true
        case let (.custom(lCode, lMsg), .custom(rCode, rMsg)):
            return lCode == rCode && lMsg == rMsg
        default:
            return false
        }
    }
}
