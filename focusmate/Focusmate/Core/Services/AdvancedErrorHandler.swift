import Foundation
import SwiftUI
import Combine

// MARK: - Enhanced Error Types
enum FocusmateError: LocalizedError {
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
    
    // Structured error properties
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
        case .serverError(let code, _, _):
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
        case .custom(let code, _):
            return code
        }
    }
    
    var message: String {
        switch self {
        case .network(let error):
            return "Network error: \(error.localizedDescription)"
        case .unauthorized(let message):
            return message ?? "You are not authorized. Please sign in again."
        case .badRequest(let message, _):
            return "Bad request: \(message)"
        case .notFound(let message):
            return message ?? "The requested resource was not found."
        case .serverError(_, let message, _):
            return message ?? "Server error occurred"
        case .decoding(let message):
            return message ?? "Failed to parse server response."
        case .validation(let errors, _):
            let errorMessages = errors.flatMap { $0.value }.joined(separator: ", ")
            return "Validation errors: \(errorMessages)"
        case .rateLimited(_, let message):
            return message ?? "Rate limit exceeded. Please try again later."
        case .timeout:
            return "Request timed out. Please try again."
        case .noInternetConnection:
            return "No internet connection. Please check your network."
        case .custom(_, let message):
            return message ?? "An unknown error occurred"
        }
    }
    
    var errorDescription: String? {
        return message
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
        case .rateLimited(let seconds, _):
            return seconds
        default:
            return nil
        }
    }
}

// MARK: - Advanced Error Handler
@MainActor
final class AdvancedErrorHandler: ObservableObject {
    static let shared = AdvancedErrorHandler()
    
    @Published var isReauthenticating = false
    @Published var retryCount: [String: Int] = [:]
    @Published var lastRetryTime: [String: Date] = [:]
    
    private let maxRetries = 3
    private let baseBackoffDelay: TimeInterval = 1.0
    private let maxBackoffDelay: TimeInterval = 60.0
    
    private init() {}
    
    // MARK: - Error Processing
    
    func handle(_ error: Error, context: String = "") -> FocusmateError {
        print("🔍 AdvancedErrorHandler: Processing error in context '\(context)': \(error)")
        
        if let apiError = error as? APIError {
            return processAPIError(apiError, context: context)
        }
        
        // Handle network errors
        if let urlError = error as? URLError {
            return processURLError(urlError, context: context)
        }
        
        return .custom("UNKNOWN_ERROR", error.localizedDescription)
    }
    
    private func processAPIError(_ error: APIError, context: String) -> FocusmateError {
        switch error {
        case .badURL:
            return .custom("BAD_URL", "Invalid URL")
        case .decoding:
            return .decoding(nil)
        case .unauthorized:
            return .unauthorized(nil)
        case .network(let error):
            return .network(error)
        case .badStatus(let code, let message, let details):
            return processHTTPStatus(code: code, message: message, details: details)
        case .rateLimited(let seconds):
            return .rateLimited(seconds, nil)
        case .serverError(let code, let message, let details):
            return .serverError(code, message, extractMessageFromDetails(details))
        case .validation(let errors):
            return .validation(errors, nil)
        case .timeout:
            return .timeout
        case .noInternetConnection:
            return .noInternetConnection
        }
    }
    
    private func processURLError(_ error: URLError, context: String) -> FocusmateError {
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
    
    private func processHTTPStatus(code: Int, message: String?, details: [String: Any]?) -> FocusmateError {
        switch code {
        case 400:
            return .badRequest(message ?? "Bad request", extractMessageFromDetails(details))
        case 401:
            return .unauthorized(message ?? "Unauthorized")
        case 404:
            return .notFound(message ?? "Not found")
        case 422:
            if let validationErrors = extractValidationErrors(from: details) {
                return .validation(validationErrors, message)
            }
            return .badRequest(message ?? "Validation failed", extractMessageFromDetails(details))
        case 429:
            let retryAfter = extractRetryAfter(from: details) ?? 60
            return .rateLimited(retryAfter, message)
        case 500...599:
            return .serverError(code, message, extractMessageFromDetails(details))
        default:
            return .serverError(code, message, extractMessageFromDetails(details))
        }
    }
    
    // MARK: - Re-authentication Handling
    
    func handleUnauthorized() async -> Bool {
        guard !isReauthenticating else {
            print("🔄 AdvancedErrorHandler: Already re-authenticating, skipping")
            return false
        }
        
        isReauthenticating = true
        print("🔄 AdvancedErrorHandler: Starting re-authentication process")
        
        // Clear stored credentials
        await clearStoredCredentials()
        
        // Navigate to sign-in
        await navigateToSignIn()
        
        isReauthenticating = false
        return true
    }
    
    private func clearStoredCredentials() async {
        // Clear JWT token and user data
        // This would integrate with your AuthStore
        print("🧹 AdvancedErrorHandler: Clearing stored credentials")
    }
    
    private func navigateToSignIn() async {
        // Navigate to sign-in screen
        // This would integrate with your navigation system
        print("🔐 AdvancedErrorHandler: Navigating to sign-in")
    }
    
    // MARK: - Rate Limiting and Backoff
    
    func shouldRetry(error: FocusmateError, context: String) -> Bool {
        guard error.isRetryable else { return false }
        
        let retryKey = "\(context)_\(error.code)"
        let currentRetries = retryCount[retryKey] ?? 0
        
        if currentRetries >= maxRetries {
            print("⏰ AdvancedErrorHandler: Max retries exceeded for \(retryKey)")
            return false
        }
        
        // Check if enough time has passed since last retry
        if let lastRetry = lastRetryTime[retryKey] {
            let timeSinceLastRetry = Date().timeIntervalSince(lastRetry)
            let requiredDelay = calculateBackoffDelay(retryCount: currentRetries)
            
            if timeSinceLastRetry < requiredDelay {
                print("⏰ AdvancedErrorHandler: Not enough time passed since last retry for \(retryKey)")
                return false
            }
        }
        
        return true
    }
    
    func recordRetryAttempt(context: String, error: FocusmateError) {
        let retryKey = "\(context)_\(error.code)"
        retryCount[retryKey, default: 0] += 1
        lastRetryTime[retryKey] = Date()
        
        print("🔄 AdvancedErrorHandler: Recorded retry attempt \(retryCount[retryKey]!) for \(retryKey)")
    }
    
    func resetRetryCount(context: String) {
        let keysToRemove = retryCount.keys.filter { $0.hasPrefix(context) }
        for key in keysToRemove {
            retryCount.removeValue(forKey: key)
            lastRetryTime.removeValue(forKey: key)
        }
        print("🔄 AdvancedErrorHandler: Reset retry count for context: \(context)")
    }
    
    private func calculateBackoffDelay(retryCount: Int) -> TimeInterval {
        let exponentialDelay = baseBackoffDelay * pow(2.0, Double(retryCount))
        return min(exponentialDelay, maxBackoffDelay)
    }
    
    // MARK: - Retry with Backoff
    
    func retryWithBackoff<T>(
        context: String,
        error: FocusmateError,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        guard shouldRetry(error: error, context: context) else {
            throw error
        }
        
        recordRetryAttempt(context: context, error: error)
        
        let delay = calculateBackoffDelay(retryCount: retryCount["\(context)_\(error.code)"] ?? 0)
        print("⏰ AdvancedErrorHandler: Waiting \(delay) seconds before retry for \(context)")
        
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        do {
            let result = try await operation()
            resetRetryCount(context: context)
            return result
        } catch {
            let newError = handle(error, context: context)
            if shouldRetry(error: newError, context: context) {
                return try await retryWithBackoff(context: context, error: newError, operation: operation)
            }
            throw newError
        }
    }
    
    // MARK: - Helper Methods
    
    private func extractMessageFromDetails(_ details: [String: Any]?) -> String? {
        guard let details = details else { return nil }
        
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
    
    private func extractValidationErrors(from details: [String: Any]?) -> [String: [String]]? {
        guard let details = details,
              let errors = details["errors"] as? [String: [String]] else {
            return nil
        }
        return errors
    }
    
    private func extractRetryAfter(from details: [String: Any]?) -> Int? {
        guard let details = details else { return nil }
        
        if let retryAfter = details["retry_after"] as? Int {
            return retryAfter
        }
        
        if let retryAfter = details["retryAfter"] as? Int {
            return retryAfter
        }
        
        return nil
    }
    
    // MARK: - Alert Generation
    
    func showAlert(for error: FocusmateError) -> Alert {
        let title = "Error"
        let message = error.message
        
        if error.code == "UNAUTHORIZED" {
            return Alert(
                title: Text(title),
                message: Text(message),
                primaryButton: .default(Text("Sign In")) {
                    Task {
                        await self.handleUnauthorized()
                    }
                },
                secondaryButton: .cancel(Text("Cancel"))
            )
        } else if error.code == "RATE_LIMITED" {
            let retryAfter = error.retryAfterSeconds ?? 60
            return Alert(
                title: Text(title),
                message: Text("\(message)\n\nPlease wait \(retryAfter) seconds before trying again."),
                dismissButton: .default(Text("OK"))
            )
        } else {
            return Alert(
                title: Text(title),
                message: Text(message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}
