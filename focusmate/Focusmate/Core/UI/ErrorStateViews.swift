import SwiftUI

// MARK: - Error State Components

/// Inline error banner with retry action
struct InlineErrorBanner: View {
  let error: Error
  let retryAction: (() async -> Void)?
  let dismissAction: (() -> Void)?

  @State private var isRetrying = false

  init(
    error: Error,
    retryAction: (() async -> Void)? = nil,
    dismissAction: (() -> Void)? = nil
  ) {
    self.error = error
    self.retryAction = retryAction
    self.dismissAction = dismissAction
  }

  private var errorMessage: String {
    if let focusmateError = error as? FocusmateError {
      return focusmateError.errorDescription ?? "An error occurred"
    }
    return error.localizedDescription
  }

  var body: some View {
    HStack(spacing: DesignSystem.Spacing.md) {
      Image(systemName: DesignSystem.Icons.error)
        .foregroundColor(DesignSystem.Colors.error)
        .font(.title3)

      VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
        Text("Error")
          .font(DesignSystem.Typography.bodyEmphasized)
          .foregroundColor(DesignSystem.Colors.textPrimary)

        Text(errorMessage)
          .font(DesignSystem.Typography.caption1)
          .foregroundColor(DesignSystem.Colors.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer()

      HStack(spacing: DesignSystem.Spacing.xs) {
        if let retryAction = retryAction {
          Button {
            Task {
              isRetrying = true
              await retryAction()
              isRetrying = false
            }
          } label: {
            if isRetrying {
              ProgressView()
                .scaleEffect(0.8)
            } else {
              Image(systemName: "arrow.clockwise")
                .foregroundColor(DesignSystem.Colors.primary)
            }
          }
          .disabled(isRetrying)
        }

        if let dismissAction = dismissAction {
          Button {
            dismissAction()
          } label: {
            Image(systemName: "xmark")
              .foregroundColor(DesignSystem.Colors.textSecondary)
          }
        }
      }
    }
    .padding(DesignSystem.Spacing.md)
    .background(DesignSystem.Colors.errorLight)
    .cornerRadius(DesignSystem.CornerRadius.md)
    .overlay(
      RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
        .stroke(DesignSystem.Colors.error, lineWidth: 1)
    )
  }
}

/// Full-screen error state with retry
struct ErrorStateView: View {
  let title: String
  let message: String
  let icon: String
  let retryAction: (() async -> Void)?

  @State private var isRetrying = false

  init(
    title: String = "Something went wrong",
    message: String = "Please try again",
    icon: String = DesignSystem.Icons.error,
    retryAction: (() async -> Void)? = nil
  ) {
    self.title = title
    self.message = message
    self.icon = icon
    self.retryAction = retryAction
  }

  init(error: Error, retryAction: (() async -> Void)? = nil) {
    if let focusmateError = error as? FocusmateError {
      self.title = focusmateError.displayTitle
      self.message = focusmateError.errorDescription ?? "Please try again"
    } else {
      self.title = "Something went wrong"
      self.message = error.localizedDescription
    }
    self.icon = DesignSystem.Icons.error
    self.retryAction = retryAction
  }

  var body: some View {
    VStack(spacing: DesignSystem.Spacing.xl) {
      Image(systemName: icon)
        .font(.system(size: 64))
        .foregroundColor(DesignSystem.Colors.error)

      VStack(spacing: DesignSystem.Spacing.sm) {
        Text(title)
          .font(DesignSystem.Typography.title3)
          .foregroundColor(DesignSystem.Colors.textPrimary)
          .multilineTextAlignment(.center)

        Text(message)
          .font(DesignSystem.Typography.body)
          .foregroundColor(DesignSystem.Colors.textSecondary)
          .multilineTextAlignment(.center)
      }

      if let retryAction = retryAction {
        Button {
          Task {
            isRetrying = true
            await retryAction()
            isRetrying = false
          }
        } label: {
          HStack {
            if isRetrying {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
              Image(systemName: "arrow.clockwise")
            }
            Text(isRetrying ? "Retrying..." : "Try Again")
          }
          .font(DesignSystem.Typography.buttonLabel)
          .foregroundColor(.white)
          .padding(.horizontal, DesignSystem.Spacing.xl)
          .padding(.vertical, DesignSystem.Spacing.md)
          .background(DesignSystem.Colors.primary)
          .cornerRadius(DesignSystem.CornerRadius.button)
        }
        .disabled(isRetrying)
      }
    }
    .padding(DesignSystem.Spacing.xl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

/// Network error state with specific messaging
struct NetworkErrorView: View {
  let retryAction: (() async -> Void)?

  var body: some View {
    ErrorStateView(
      title: "No Connection",
      message: "Please check your internet connection and try again",
      icon: "wifi.slash",
      retryAction: retryAction
    )
  }
}

/// Empty state view (not an error, but similar pattern)
struct EmptyStateView: View {
  let title: String
  let message: String
  let icon: String
  let actionTitle: String?
  let action: (() -> Void)?

  init(
    title: String,
    message: String,
    icon: String = DesignSystem.Icons.empty,
    actionTitle: String? = nil,
    action: (() -> Void)? = nil
  ) {
    self.title = title
    self.message = message
    self.icon = icon
    self.actionTitle = actionTitle
    self.action = action
  }

  var body: some View {
    VStack(spacing: DesignSystem.Spacing.xl) {
      Image(systemName: icon)
        .font(.system(size: 64))
        .foregroundColor(DesignSystem.Colors.textSecondary)

      VStack(spacing: DesignSystem.Spacing.sm) {
        Text(title)
          .font(DesignSystem.Typography.title3)
          .foregroundColor(DesignSystem.Colors.textPrimary)
          .multilineTextAlignment(.center)

        Text(message)
          .font(DesignSystem.Typography.body)
          .foregroundColor(DesignSystem.Colors.textSecondary)
          .multilineTextAlignment(.center)
      }

      if let actionTitle = actionTitle, let action = action {
        Button(action: action) {
          Text(actionTitle)
            .font(DesignSystem.Typography.buttonLabel)
            .foregroundColor(.white)
            .padding(.horizontal, DesignSystem.Spacing.xl)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.primary)
            .cornerRadius(DesignSystem.CornerRadius.button)
        }
      }
    }
    .padding(DesignSystem.Spacing.xl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// MARK: - Error Handling Extension for FocusmateError

extension FocusmateError {
  var displayTitle: String {
    switch self {
    case .network:
      return "Connection Error"
    case .unauthorized:
      return "Authentication Required"
    case .badRequest:
      return "Bad Request"
    case .notFound:
      return "Not Found"
    case .validation:
      return "Validation Error"
    case .serverError:
      return "Server Error"
    case .rateLimited:
      return "Too Many Requests"
    case .timeout:
      return "Request Timeout"
    case .noInternetConnection:
      return "No Internet Connection"
    case .decoding:
      return "Data Error"
    case .custom:
      return "Error"
    }
  }
}

// MARK: - View Extensions

extension View {
  /// Show an inline error banner at the top of the view
  @ViewBuilder
  func errorBanner<E: Error>(
    error: Binding<E?>,
    retryAction: (() async -> Void)? = nil
  ) -> some View {
    VStack(spacing: 0) {
      if let errorValue = error.wrappedValue {
        InlineErrorBanner(
          error: errorValue,
          retryAction: retryAction,
          dismissAction: {
            error.wrappedValue = nil
          }
        )
        .padding(DesignSystem.Spacing.padding)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(DesignSystem.Animation.spring, value: error.wrappedValue != nil)
      }

      self
    }
  }

  /// Replace content with error state when error occurs
  @ViewBuilder
  func errorState<E: Error>(
    error: Binding<E?>,
    retryAction: (() async -> Void)? = nil
  ) -> some View {
    if let errorValue = error.wrappedValue {
      ErrorStateView(error: errorValue, retryAction: retryAction)
    } else {
      self
    }
  }
}

// MARK: - Previews

#if DEBUG
  struct ErrorStateViews_Previews: PreviewProvider {
    static var previews: some View {
      Group {
        // Inline error banner
        InlineErrorBanner(
          error: FocusmateError.network(URLError(.notConnectedToInternet)),
          retryAction: {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
          },
          dismissAction: {}
        )
        .padding()
        .previewDisplayName("Inline Error Banner")

        // Full error state
        ErrorStateView(
          error: FocusmateError.network(URLError(.notConnectedToInternet)),
          retryAction: {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
          }
        )
        .previewDisplayName("Error State")

        // Network error
        NetworkErrorView(retryAction: {
          try? await Task.sleep(nanoseconds: 1_000_000_000)
        })
        .previewDisplayName("Network Error")

        // Empty state
        EmptyStateView(
          title: "No Tasks Yet",
          message: "Tap the + button to create your first task",
          icon: "list.bullet",
          actionTitle: "Create Task",
          action: {}
        )
        .previewDisplayName("Empty State")
      }
    }
  }
#endif
