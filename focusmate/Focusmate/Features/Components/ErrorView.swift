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
            .font(.system(size: DS.Size.iconJumbo))
            .foregroundStyle(DS.Colors.error)
    }

    var titleText: some View {
        Text(error.title)
            .font(.title2.weight(.semibold))
            .multilineTextAlignment(.center)
    }

    var messageText: some View {
        Text(error.message)
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }

    @ViewBuilder
    var actionButtons: some View {
        VStack(spacing: DS.Spacing.md) {
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
            Label("Try Again", systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    func dismissButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Dismiss")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
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
                .padding(DS.Spacing.md)
                .background(DS.Colors.error)
                .cornerRadius(DS.Radius.md)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
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

            textContent

            Spacer()

            actionButtons
        }
    }

    var textContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(error.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)

            Text(error.message)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
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
                .foregroundStyle(.white)
                .padding(DS.Spacing.sm)
                .background(.white.opacity(0.2))
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
                .foregroundStyle(.white)
                .padding(DS.Spacing.sm)
        }
    }
}
