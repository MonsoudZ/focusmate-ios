import Foundation

/// Stateless mapper that converts API and network errors to FocusmateError.
/// All methods are nonisolated and pure — no side effects, fully testable.
enum ErrorMapper {

    // MARK: - Public API

    /// Maps any error to a FocusmateError.
    static func map(_ error: Error) -> FocusmateError {
        if let apiError = error as? APIError {
            return mapAPIError(apiError)
        }

        if let urlError = error as? URLError {
            return mapURLError(urlError)
        }

        return .custom("UNKNOWN_ERROR", error.localizedDescription)
    }

    // MARK: - API Error Mapping

    static func mapAPIError(_ error: APIError) -> FocusmateError {
        switch error {
        case .badURL:
            return .custom("BAD_URL", "Invalid URL")
        case .decoding:
            return .decoding(nil)
        case let .unauthorized(message):
            return .unauthorized(message)
        case let .network(underlyingError):
            return .network(underlyingError)
        case let .badStatus(code, message, details):
            return mapHTTPStatus(code: code, message: message, details: details)
        case let .rateLimited(seconds):
            return .rateLimited(seconds, nil)
        case let .serverError(code, message, details):
            return .serverError(code, message, extractMessage(from: details))
        case let .validation(errors):
            return .validation(errors, nil)
        case .timeout:
            return .timeout
        case .noInternetConnection:
            return .noInternetConnection
        }
    }

    // MARK: - URL Error Mapping

    static func mapURLError(_ error: URLError) -> FocusmateError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noInternetConnection
        case .timedOut:
            return .timeout
        case .cannotConnectToHost, .cannotFindHost:
            return .network(error)
        default:
            return .network(error)
        }
    }

    // MARK: - HTTP Status Mapping

    static func mapHTTPStatus(code: Int, message: String?, details: [String: Any]?) -> FocusmateError {
        switch code {
        case 400:
            return .badRequest(message ?? "Bad request", extractMessage(from: details))
        case 401:
            return .unauthorized(message ?? "Unauthorized")
        case 404:
            return .notFound(message ?? "Not found")
        case 422:
            if let validationErrors = extractValidationErrors(from: details) {
                return .validation(validationErrors, message)
            }
            return .badRequest(message ?? "Validation failed", extractMessage(from: details))
        case 429:
            let retryAfter = extractRetryAfter(from: details) ?? 60
            return .rateLimited(retryAfter, message)
        case 500...599:
            return .serverError(code, message, extractMessage(from: details))
        default:
            return .serverError(code, message, extractMessage(from: details))
        }
    }

    // MARK: - Detail Extraction Helpers

    static func extractMessage(from details: [String: Any]?) -> String? {
        guard let details else { return nil }

        if let message = details["message"] as? String {
            return message
        }

        if let errors = details["errors"] as? [String: Any] {
            let errorMessages = errors.compactMap { key, value in
                if let valueArray = value as? [String] {
                    return "\(key): \(valueArray.joined(separator: ", "))"
                }
                return nil
            }
            return errorMessages.joined(separator: "; ")
        }

        return nil
    }

    static func extractValidationErrors(from details: [String: Any]?) -> [String: [String]]? {
        guard let details,
              let errors = details["errors"] as? [String: [String]]
        else {
            return nil
        }
        return errors
    }

    static func extractRetryAfter(from details: [String: Any]?) -> Int? {
        guard let details else { return nil }

        if let retryAfter = details["retry_after"] as? Int {
            return retryAfter
        }

        if let retryAfter = details["retryAfter"] as? Int {
            return retryAfter
        }

        return nil
    }
}
