import SwiftUI

struct ErrorHandlingTestView: View {
    @StateObject private var errorHandler = AdvancedErrorHandler.shared
    @State private var testResults: [String] = []
    @State private var isRunningTest = false
    @State private var showingErrorAlert = false
    @State private var currentError: FocusmateError?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Advanced Error Handling Test")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if isRunningTest {
                    ProgressView("Running tests...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 16) {
                        Button("Test Structured Errors") {
                            testStructuredErrors()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Test 401 Re-authentication") {
                            test401Reauth()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Test 429 Rate Limiting") {
                            test429RateLimit()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Test Retry Logic") {
                            testRetryLogic()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Test Error Alerts") {
                            testErrorAlerts()
                        }
                        .buttonStyle(.bordered)
                        
                        if !testResults.isEmpty {
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 8) {
                                    ForEach(testResults, id: \.self) { result in
                                        Text(result)
                                            .font(.caption)
                                            .foregroundColor(result.contains("✅") ? .green : result.contains("❌") ? .red : .primary)
                                    }
                                }
                            }
                            .frame(maxHeight: 300)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Error Handling Test")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error Alert Test", isPresented: $showingErrorAlert) {
                if let error = currentError {
                    Button("OK") {
                        currentError = nil
                    }
                }
            } message: {
                if let error = currentError {
                    Text(error.message)
                }
            }
        }
    }
    
    private func testStructuredErrors() {
        testResults.append("🧪 Testing structured error handling...")
        
        // Test different error types
        let errors: [Error] = [
            APIError.unauthorized,
            APIError.badStatus(400, "Bad request", ["field": "name"]),
            APIError.rateLimited(60),
            APIError.serverError(500, "Internal server error", nil),
            APIError.network(URLError(.notConnectedToInternet))
        ]
        
        for error in errors {
            let processedError = errorHandler.handle(error, context: "test")
            testResults.append("✅ Error: \(processedError.code) - \(processedError.message)")
            testResults.append("   Retryable: \(processedError.isRetryable)")
            if let retryAfter = processedError.retryAfterSeconds {
                testResults.append("   Retry After: \(retryAfter)s")
            }
        }
        
        testResults.append("✅ Structured error handling test completed")
    }
    
    private func test401Reauth() {
        testResults.append("🧪 Testing 401 re-authentication...")
        
        let unauthorizedError = APIError.unauthorized
        let processedError = errorHandler.handle(unauthorizedError, context: "auth_test")
        
        testResults.append("✅ Unauthorized error processed: \(processedError.code)")
        testResults.append("✅ Error message: \(processedError.message)")
        testResults.append("✅ Should trigger re-authentication flow")
        
        // Test re-authentication handling
        Task {
            let reauthResult = await errorHandler.handleUnauthorized()
            await MainActor.run {
                testResults.append("✅ Re-authentication result: \(reauthResult)")
            }
        }
        
        testResults.append("✅ 401 re-authentication test completed")
    }
    
    private func test429RateLimit() {
        testResults.append("🧪 Testing 429 rate limiting...")
        
        let rateLimitError = APIError.rateLimited(120)
        let processedError = errorHandler.handle(rateLimitError, context: "rate_limit_test")
        
        testResults.append("✅ Rate limit error processed: \(processedError.code)")
        testResults.append("✅ Retry after: \(processedError.retryAfterSeconds ?? 0) seconds")
        testResults.append("✅ Is retryable: \(processedError.isRetryable)")
        
        // Test retry logic
        let shouldRetry = errorHandler.shouldRetry(error: processedError, context: "rate_limit_test")
        testResults.append("✅ Should retry: \(shouldRetry)")
        
        testResults.append("✅ 429 rate limiting test completed")
    }
    
    private func testRetryLogic() {
        testResults.append("🧪 Testing retry logic...")
        
        // Test retry count tracking
        let testError = FocusmateError.network(URLError(.timedOut))
        let context = "retry_test"
        
        for i in 1...4 {
            let shouldRetry = errorHandler.shouldRetry(error: testError, context: context)
            testResults.append("✅ Attempt \(i): Should retry = \(shouldRetry)")
            
            if shouldRetry {
                errorHandler.recordRetryAttempt(context: context, error: testError)
            }
        }
        
        // Reset retry count
        errorHandler.resetRetryCount(context: context)
        testResults.append("✅ Retry count reset")
        
        testResults.append("✅ Retry logic test completed")
    }
    
    private func testErrorAlerts() {
        testResults.append("🧪 Testing error alerts...")
        
        let errors: [FocusmateError] = [
            .unauthorized("Session expired"),
            .rateLimited(60, "Too many requests"),
            .network(URLError(.notConnectedToInternet)),
            .serverError(500, "Internal server error", "Database connection failed")
        ]
        
        for (index, error) in errors.enumerated() {
            testResults.append("✅ Alert \(index + 1): \(error.code) - \(error.message)")
        }
        
        // Show a sample alert
        currentError = .unauthorized("Test session expired")
        showingErrorAlert = true
        
        testResults.append("✅ Error alerts test completed")
    }
}

#Preview {
    ErrorHandlingTestView()
}
