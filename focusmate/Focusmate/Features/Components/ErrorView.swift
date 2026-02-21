import SwiftUI

// MARK: - ErrorView

struct ErrorView: View {
  let error: FocusmateError
  let onRetry: (() async -> Void)?
  let onDismiss: (() -> Void)?

  var body: some View {
    VStack(spacing: DS.Spacing.xl) {
      errorIcon
      titleText
      messageText
      actionButtons
    }
    .padding()
  }
}

// MARK: - ErrorView Subviews

private extension ErrorView {
  var errorIcon: some View {
    Image(systemName: iconName)
      .scaledFont(size: 64, relativeTo: .largeTitle)
      .foregroundStyle(DS.Colors.error)
  }

  var titleText: some View {
    Text(self.error.title)
      .font(DS.Typography.title2)
      .multilineTextAlignment(.center)
  }

  var messageText: some View {
    Text(self.error.message)
      .font(DS.Typography.body)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
      .padding(.horizontal)
  }

  var actionButtons: some View {
    VStack(spacing: DS.Spacing.md) {
      if self.error.isRetryable, let onRetry {
        self.retryButton(action: onRetry)
      }
      if let onDismiss {
        self.dismissButton(action: onDismiss)
      }
    }
    .padding(.horizontal)
  }

  func retryButton(action: @escaping () async -> Void) -> some View {
    Button {
      Task { await action() }
    } label: {
      Label("Try Again", systemImage: "arrow.clockwise")
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(IntentiaPrimaryButtonStyle())
  }

  func dismissButton(action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text("Dismiss")
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(IntentiaSecondaryButtonStyle())
  }
}

// MARK: - ErrorView Helpers

private extension ErrorView {
  var iconName: String {
    switch self.error {
    case .noInternetConnection: "wifi.slash"
    case .unauthorized: "lock.fill"
    case .notFound: "magnifyingglass"
    case .rateLimited: "clock.fill"
    case .timeout: "hourglass"
    case .network: "wifi.exclamationmark"
    case .validation: "exclamationmark.circle.fill"
    case .badRequest, .serverError, .decoding, .custom: "exclamationmark.triangle.fill"
    }
  }
}

// MARK: - ErrorBanner

struct ErrorBanner: View {
  let error: FocusmateError
  let onRetry: (() async -> Void)?
  let onDismiss: () -> Void

  @State private var isVisible = true

  var body: some View {
    if self.isVisible {
      bannerContent
        .padding(DS.Spacing.md)
        .background(DS.Colors.error)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .shadow(DS.Shadow.sm)
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
  }
}

// MARK: - ErrorBanner Subviews

private extension ErrorBanner {
  var bannerContent: some View {
    HStack(spacing: DS.Spacing.md) {
      Image(systemName: "exclamationmark.circle.fill")
        .foregroundStyle(.white)

      self.textContent

      Spacer()

      self.actionButtons
    }
  }

  var textContent: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
      Text(self.error.title)
        .font(DS.Typography.subheadline.weight(.medium))
        .foregroundStyle(.white)

      Text(self.error.message)
        .font(DS.Typography.caption)
        .foregroundStyle(.white.opacity(0.9))
        .lineLimit(2)
    }
  }

  @ViewBuilder
  var actionButtons: some View {
    if self.error.isRetryable, let onRetry {
      self.retryButton(action: onRetry)
    }
    self.closeButton
  }

  func retryButton(action: @escaping () async -> Void) -> some View {
    Button {
      Task { await action() }
    } label: {
      Image(systemName: "arrow.clockwise")
        .foregroundStyle(.white)
        .padding(DS.Spacing.sm)
        .background(.white.opacity(0.2))
        .clipShape(Circle())
    }
  }

  var closeButton: some View {
    Button {
      withMotionAnimation {
        self.isVisible = false
      }
      self.onDismiss()
    } label: {
      Image(systemName: "xmark")
        .foregroundStyle(.white)
        .padding(DS.Spacing.sm)
    }
  }
}
