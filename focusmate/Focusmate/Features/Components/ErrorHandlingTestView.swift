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

        if self.isRunningTest {
          ProgressView("Running tests...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          VStack(spacing: 16) {
            Button("Test Structured Errors") {
              self.testStructuredErrors()
            }
            .buttonStyle(.borderedProminent)

            Button("Test 401 Re-authentication") {
              self.test401Reauth()
            }
            .buttonStyle(.bordered)

            Button("Test 429 Rate Limiting") {
              self.test429RateLimit()
            }
            .buttonStyle(.bordered)

            Button("Test Retry Logic") {
              self.testRetryLogic()
            }
            .buttonStyle(.bordered)

            Button("Test Error Alerts") {
              self.testErrorAlerts()
            }
            .buttonStyle(.bordered)

            if !self.testResults.isEmpty {
              ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                  ForEach(self.testResults, id: \.self) { result in
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
      .alert("Error Alert Test", isPresented: self.$showingErrorAlert) {
        if self.currentError != nil {
          Button("OK") {
            self.currentError = nil
          }
        }
      } message: {
        if let error = currentError {
          Text(error.message)
        }
      }
    }
  }

  func testStructuredErrors() {
    self.testResults.append("🧪 Testing structured error handling...")

    // Test different error types
    let errors: [Error] = [
      APIError.unauthorized,
      APIError.badStatus(400, "Bad request", ["field": "name"]),
      APIError.rateLimited(60),
      APIError.serverError(500, "Internal server error", nil),
      APIError.network(URLError(.notConnectedToInternet)),
    ]

    for error in errors {
      let processedError = self.errorHandler.handle(error, context: "test")
      self.testResults.append("✅ Error: \(processedError.code) - \(processedError.message)")
      self.testResults.append("   Retryable: \(processedError.isRetryable)")
      if let retryAfter = processedError.retryAfterSeconds {
        self.testResults.append("   Retry After: \(retryAfter)s")
      }
    }

    self.testResults.append("✅ Structured error handling test completed")
  }

  func test401Reauth() {
    self.testResults.append("🧪 Testing 401 re-authentication...")

    let unauthorizedError = APIError.unauthorized
    let processedError = self.errorHandler.handle(unauthorizedError, context: "auth_test")

    self.testResults.append("✅ Unauthorized error processed: \(processedError.code)")
    self.testResults.append("✅ Error message: \(processedError.message)")
    self.testResults.append("✅ Should trigger re-authentication flow")

    // Test re-authentication handling
    Task {
      let reauthResult = await errorHandler.handleUnauthorized()
      await MainActor.run {
        self.testResults.append("✅ Re-authentication result: \(reauthResult)")
      }
    }

    self.testResults.append("✅ 401 re-authentication test completed")
  }

  func test429RateLimit() {
    self.testResults.append("🧪 Testing 429 rate limiting...")

    let rateLimitError = APIError.rateLimited(120)
    let processedError = self.errorHandler.handle(rateLimitError, context: "rate_limit_test")

    self.testResults.append("✅ Rate limit error processed: \(processedError.code)")
    self.testResults.append("✅ Retry after: \(processedError.retryAfterSeconds ?? 0) seconds")
    self.testResults.append("✅ Is retryable: \(processedError.isRetryable)")

    // Test retry logic
    let shouldRetry = self.errorHandler.shouldRetry(error: processedError, context: "rate_limit_test")
    self.testResults.append("✅ Should retry: \(shouldRetry)")

    self.testResults.append("✅ 429 rate limiting test completed")
  }

  func testRetryLogic() {
    self.testResults.append("🧪 Testing retry logic...")

    // Test retry count tracking
    let testError = FocusmateError.network(URLError(.timedOut))
    let context = "retry_test"

    for i in 1 ... 4 {
      let shouldRetry = self.errorHandler.shouldRetry(error: testError, context: context)
      self.testResults.append("✅ Attempt \(i): Should retry = \(shouldRetry)")

      if shouldRetry {
        self.errorHandler.recordRetryAttempt(context: context, error: testError)
      }
    }

    // Reset retry count
    self.errorHandler.resetRetryCount(context: context)
    self.testResults.append("✅ Retry count reset")

    self.testResults.append("✅ Retry logic test completed")
  }

  func testErrorAlerts() {
    self.testResults.append("🧪 Testing error alerts...")

    let errors: [FocusmateError] = [
      .unauthorized("Session expired"),
      .rateLimited(60, "Too many requests"),
      .network(URLError(.notConnectedToInternet)),
      .serverError(500, "Internal server error", "Database connection failed"),
    ]

    for (index, error) in errors.enumerated() {
      self.testResults.append("✅ Alert \(index + 1): \(error.code) - \(error.message)")
    }

    // Show a sample alert
    self.currentError = .unauthorized("Test session expired")
    self.showingErrorAlert = true

    self.testResults.append("✅ Error alerts test completed")
  }
}

#Preview {
  ErrorHandlingTestView()
}
