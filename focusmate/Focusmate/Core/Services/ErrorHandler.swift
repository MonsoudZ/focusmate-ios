import Foundation
import SwiftUI

enum FocusmateError: LocalizedError {
    case network(Error)
    case unauthorized
    case badRequest(String)
    case notFound
    case serverError(Int)
    case decoding
    case validation([String: [String]])
    case custom(String)
    
    var errorDescription: String? {
        switch self {
        case .network(let error):
            return "Network error: \(error.localizedDescription)"
        case .unauthorized:
            return "You are not authorized. Please sign in again."
        case .badRequest(let message):
            return "Bad request: \(message)"
        case .notFound:
            return "The requested resource was not found."
        case .serverError(let code):
            return "Server error: \(code)"
        case .decoding:
            return "Failed to parse server response."
        case .validation(let errors):
            let errorMessages = errors.flatMap { $0.value }.joined(separator: ", ")
            return "Validation errors: \(errorMessages)"
        case .custom(let message):
            return message
        }
    }
}

final class ErrorHandler {
    static let shared = ErrorHandler()
    private init() {}
    
    func handle(_ error: Error) -> FocusmateError {
        if let apiError = error as? APIError {
            switch apiError {
            case .network(let error):
                return .network(error)
            case .unauthorized:
                return .unauthorized
            case .badStatus(let code):
                return .serverError(code)
            case .decoding:
                return .decoding
            case .badURL:
                return .custom("Invalid URL")
            }
        }
        
        return .custom(error.localizedDescription)
    }
    
    func showAlert(for error: FocusmateError) -> Alert {
        Alert(
            title: Text("Error"),
            message: Text(error.errorDescription ?? "An unknown error occurred"),
            dismissButton: .default(Text("OK"))
        )
    }
}
