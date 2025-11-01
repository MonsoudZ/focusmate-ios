import SwiftUI

/// Enhanced error view with retry and recovery options
struct ErrorView: View {
  let error: FocusmateError
  let context: String
  let onRetry: (() async -> Void)?
  let onDismiss: (() -> Void)?

  init(
    error: FocusmateError,
    context: String = "",
    onRetry: (() async -> Void)? = nil,
    onDismiss: (() -> Void)? = nil
  ) {
    self.error = error
    self.context = context
    self.onRetry = onRetry
    self.onDismiss = onDismiss
  }

  var body: some View {
    VStack(spacing: 20) {
      // Error Icon
      Image(systemName: errorIcon)
        .font(.system(size: 60))
        .foregroundColor(errorColor)

      // Error Title
      Text(errorTitle)
        .font(.title2)
        .fontWeight(.bold)
        .multilineTextAlignment(.center)

      // Error Message
      Text(error.message)
        .font(.body)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)

      // Additional Info
      if let additionalInfo = getAdditionalInfo() {
        Text(additionalInfo)
          .font(.caption)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal)
      }

      // Actions
      VStack(spacing: 12) {
        // Retry Button
        if error.isRetryable, let onRetry = onRetry {
          Button {
            Task {
              await onRetry()
            }
          } label: {
            HStack {
              Image(systemName: "arrow.clockwise")
              Text("Try Again")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
          }
        }

        // Dismiss Button
        if let onDismiss = onDismiss {
          Button {
            onDismiss()
          } label: {
            Text("Dismiss")
              .frame(maxWidth: .infinity)
              .padding()
              .background(Color.gray.opacity(0.2))
              .foregroundColor(.primary)
              .clipShape(RoundedRectangle(cornerRadius: 12))
          }
        }
      }
      .padding(.horizontal)
    }
    .padding()
  }

  private var errorIcon: String {
    switch error.code {
    case "NO_INTERNET":
      return "wifi.slash"
    case "UNAUTHORIZED":
      return "lock.fill"
    case "NOT_FOUND":
      return "exclamationmark.magnifyingglass"
    case "RATE_LIMITED":
      return "clock.fill"
    case "TIMEOUT":
      return "hourglass"
    case "VALIDATION_ERROR":
      return "checkmark.shield.fill"
    default:
      return "exclamationmark.triangle.fill"
    }
  }

  private var errorColor: Color {
    switch error.code {
    case "NO_INTERNET":
      return .orange
    case "UNAUTHORIZED":
      return .red
    case "VALIDATION_ERROR":
      return .yellow
    default:
      return .red
    }
  }

  private var errorTitle: String {
    switch error.code {
    case "NO_INTERNET":
      return "No Internet Connection"
    case "UNAUTHORIZED":
      return "Authentication Required"
    case "NOT_FOUND":
      return "Not Found"
    case "RATE_LIMITED":
      return "Too Many Requests"
    case "TIMEOUT":
      return "Request Timed Out"
    case "VALIDATION_ERROR":
      return "Invalid Input"
    case let code where code.starts(with: "SERVER_ERROR"):
      return "Server Error"
    default:
      return "Something Went Wrong"
    }
  }

  private func getAdditionalInfo() -> String? {
    switch error.code {
    case "NO_INTERNET":
      return "Please check your internet connection and try again."
    case "RATE_LIMITED":
      if let retryAfter = error.retryAfterSeconds {
        return "Please wait \(retryAfter) seconds before trying again."
      }
      return "You've made too many requests. Please wait a moment."
    case "TIMEOUT":
      return "The server is taking too long to respond. Please try again."
    default:
      return nil
    }
  }
}

/// Inline error banner for smaller errors
struct ErrorBanner: View {
  let error: FocusmateError
  let onRetry: (() async -> Void)?
  let onDismiss: () -> Void

  @State private var isVisible = true

  var body: some View {
    if isVisible {
      HStack(spacing: 12) {
        Image(systemName: "exclamationmark.circle.fill")
          .foregroundColor(.white)

        VStack(alignment: .leading, spacing: 4) {
          Text(bannerTitle)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.white)

          Text(error.message)
            .font(.caption)
            .foregroundColor(.white.opacity(0.9))
            .lineLimit(2)
        }

        Spacer()

        if error.isRetryable, let onRetry = onRetry {
          Button {
            Task {
              await onRetry()
            }
          } label: {
            Image(systemName: "arrow.clockwise")
              .foregroundColor(.white)
              .padding(8)
              .background(Color.white.opacity(0.2))
              .clipShape(Circle())
          }
        }

        Button {
          withAnimation {
            isVisible = false
          }
          onDismiss()
        } label: {
          Image(systemName: "xmark")
            .foregroundColor(.white)
            .padding(8)
        }
      }
      .padding()
      .background(bannerColor)
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .shadow(radius: 4)
      .padding(.horizontal)
      .transition(.move(edge: .top).combined(with: .opacity))
    }
  }

  private var bannerTitle: String {
    switch error.code {
    case "NO_INTERNET":
      return "No Internet"
    case "UNAUTHORIZED":
      return "Authentication Required"
    case "RATE_LIMITED":
      return "Too Many Requests"
    case "TIMEOUT":
      return "Timeout"
    default:
      return "Error"
    }
  }

  private var bannerColor: Color {
    switch error.code {
    case "NO_INTERNET":
      return .orange
    case "UNAUTHORIZED":
      return .red
    case "VALIDATION_ERROR":
      return .yellow
    default:
      return .red.opacity(0.9)
    }
  }
}

/// Empty state view when data fails to load
struct ErrorEmptyState: View {
  let title: String
  let message: String
  let icon: String
  let onRetry: (() async -> Void)?

  init(
    title: String = "Unable to Load Data",
    message: String = "Something went wrong while loading your data.",
    icon: String = "exclamationmark.triangle",
    onRetry: (() async -> Void)? = nil
  ) {
    self.title = title
    self.message = message
    self.icon = icon
    self.onRetry = onRetry
  }

  var body: some View {
    VStack(spacing: 20) {
      Image(systemName: icon)
        .font(.system(size: 60))
        .foregroundColor(.secondary)

      Text(title)
        .font(.title3)
        .fontWeight(.medium)

      Text(message)
        .font(.subheadline)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)

      if let onRetry = onRetry {
        Button {
          Task {
            await onRetry()
          }
        } label: {
          HStack {
            Image(systemName: "arrow.clockwise")
            Text("Try Again")
          }
          .padding(.horizontal, 24)
          .padding(.vertical, 12)
          .background(Color.blue)
          .foregroundColor(.white)
          .clipShape(RoundedRectangle(cornerRadius: 10))
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

#Preview("Error View - Network") {
  ErrorView(
    error: .network(NSError(domain: "", code: -1)),
    onRetry: {},
    onDismiss: {}
  )
}

#Preview("Error View - No Internet") {
  ErrorView(
    error: .noInternetConnection,
    onRetry: {},
    onDismiss: {}
  )
}

#Preview("Error Banner") {
  ErrorBanner(
    error: .timeout,
    onRetry: {},
    onDismiss: {}
  )
}

#Preview("Error Empty State") {
  ErrorEmptyState(
    onRetry: {}
  )
}
