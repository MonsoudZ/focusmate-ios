import SwiftUI

// MARK: - ErrorView

struct ErrorView: View {
    let error: FocusmateError
    let onRetry: (() async -> Void)?
    let onDismiss: (() -> Void)?

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
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
            .font(.system(size: 60))
            .foregroundColor(DesignSystem.Colors.error)
    }

    var titleText: some View {
        Text(error.title)
            .font(DesignSystem.Typography.title2)
            .multilineTextAlignment(.center)
    }

    var messageText: some View {
        Text(error.message)
            .font(DesignSystem.Typography.body)
            .foregroundColor(DesignSystem.Colors.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }

    @ViewBuilder
    var actionButtons: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            if error.isRetryable, let onRetry {
                retryButton(action: onRetry)
            }
            if let onDismiss {
                dismissButton(action: onDismiss)
            }
        }
        .padding(.horizontal)
    }

    func retryButton(action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            HStack {
                Image(systemName: "arrow.clockwise")
                Text("Try Again")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(DesignSystem.Colors.primary)
            .foregroundColor(.white)
            .cornerRadius(DesignSystem.CornerRadius.button)
        }
    }

    func dismissButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Dismiss")
                .frame(maxWidth: .infinity)
                .padding()
                .background(DesignSystem.Colors.cardBackground)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .cornerRadius(DesignSystem.CornerRadius.button)
        }
    }
}

// MARK: - ErrorView Helpers

private extension ErrorView {
    var iconName: String {
        switch error {
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
        if isVisible {
            bannerContent
                .padding()
                .background(DesignSystem.Colors.error)
                .cornerRadius(DesignSystem.CornerRadius.md)
                .shadow(
                    color: DesignSystem.Shadow.small.color,
                    radius: DesignSystem.Shadow.small.radius,
                    x: DesignSystem.Shadow.small.x,
                    y: DesignSystem.Shadow.small.y
                )
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - ErrorBanner Subviews

private extension ErrorBanner {
    var bannerContent: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.white)

            textContent

            Spacer()

            actionButtons
        }
    }

    var textContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            Text(error.title)
                .font(DesignSystem.Typography.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)

            Text(error.message)
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(2)
        }
    }

    @ViewBuilder
    var actionButtons: some View {
        if error.isRetryable, let onRetry {
            retryButton(action: onRetry)
        }
        closeButton
    }

    func retryButton(action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Image(systemName: "arrow.clockwise")
                .foregroundColor(.white)
                .padding(8)
                .background(Color.white.opacity(0.2))
                .clipShape(Circle())
        }
    }

    var closeButton: some View {
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
}
