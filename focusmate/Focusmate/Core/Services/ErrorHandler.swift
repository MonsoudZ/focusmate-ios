import Foundation
import SwiftUI

// MARK: - Legacy ErrorHandler (Backward Compatibility)
final class ErrorHandler {
    static let shared = ErrorHandler()
    private let advancedHandler = AdvancedErrorHandler.shared
    
    private init() {}
    
    func handle(_ error: Error, context: String = "") -> FocusmateError {
        return advancedHandler.handle(error, context: context)
    }
    
    func showAlert(for error: FocusmateError) -> Alert {
        return advancedHandler.showAlert(for: error)
    }
    
    // MARK: - Enhanced Methods
    
    func handleWithRetry<T>(
        context: String,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        do {
            return try await operation()
        } catch {
            let processedError = handle(error, context: context)
            
            if processedError.isRetryable {
                return try await advancedHandler.retryWithBackoff(
                    context: context,
                    error: processedError,
                    operation: operation
                )
            }
            
            throw processedError
        }
    }
    
    func handleUnauthorized() async -> Bool {
        return await advancedHandler.handleUnauthorized()
    }
    
    func shouldRetry(error: FocusmateError, context: String) -> Bool {
        return advancedHandler.shouldRetry(error: error, context: context)
    }
}
