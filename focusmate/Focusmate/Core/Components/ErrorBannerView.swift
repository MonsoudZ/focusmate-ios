import SwiftUI

struct ErrorBannerView: View {
    let error: FocusmateError
    let onDismiss: () -> Void
    let onRetry: (() -> Void)?
    
    init(error: FocusmateError, onDismiss: @escaping () -> Void, onRetry: (() -> Void)? = nil) {
        self.error = error
        self.onDismiss = onDismiss
        self.onRetry = onRetry
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                
                Text(error.title)
                    .font(.headline)
                
                Spacer()
                
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: DS.Icon.close)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Text(error.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            if error.isRetryable, let onRetry {
                Button {
                    onRetry()
                } label: {
                    Label("Try Again", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.medium))
                }
                .padding(.top, DS.Spacing.xs)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.error.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(DS.Colors.error.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    private var iconName: String {
        switch error.code {
        case "NO_INTERNET", "NETWORK_ERROR":
            return "wifi.slash"
        case "UNAUTHORIZED":
            return DS.Icon.lock
        case "NOT_FOUND":
            return DS.Icon.search
        case "TIMEOUT":
            return DS.Icon.clock
        case "RATE_LIMITED":
            return "hand.raised"
        default:
            return DS.Icon.overdue
        }
    }
    
    private var iconColor: Color {
        switch error.code {
        case "UNAUTHORIZED", "NOT_FOUND":
            return DS.Colors.warning
        case _ where error.code.hasPrefix("SERVER_ERROR"):
            return DS.Colors.error
        default:
            return DS.Colors.error
        }
    }
}

// MARK: - View Modifier for easy use

struct ErrorBannerModifier: ViewModifier {
    @Binding var error: FocusmateError?
    let onRetry: (() -> Void)?

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            if let error {
                ErrorBannerView(
                    error: error,
                    onDismiss: { self.error = nil },
                    onRetry: onRetry
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.vertical, DS.Spacing.sm)
            }

            content
                .frame(maxHeight: .infinity)
        }
        .animation(.easeInOut(duration: 0.3), value: error != nil)
    }
}

// MARK: - Floating Overlay Modifier

/// A floating error banner that stays pinned to the top of the screen,
/// visible regardless of scroll position. Ideal for forms and scrollable content.
struct FloatingErrorBannerModifier: ViewModifier {
    @Binding var error: FocusmateError?
    let onRetry: (() async -> Void)?

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top) {
                if let error {
                    FloatingErrorBanner(
                        error: error,
                        onRetry: onRetry,
                        onDismiss: { self.error = nil }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: error != nil)
    }
}

/// Floating error banner view with async retry support
struct FloatingErrorBanner: View {
    let error: FocusmateError
    let onRetry: (() async -> Void)?
    let onDismiss: () -> Void

    @State private var isRetrying = false

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text(error.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(error.message)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
            }

            Spacer()

            if error.isRetryable, let onRetry {
                Button {
                    isRetrying = true
                    Task {
                        await onRetry()
                        isRetrying = false
                    }
                } label: {
                    if isRetrying {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 32, height: 32)
                .background(.white.opacity(0.2))
                .clipShape(Circle())
                .disabled(isRetrying)
            }

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(width: 28, height: 28)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.error)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .padding(.horizontal, DS.Spacing.md)
        .padding(.top, DS.Spacing.xs)
    }
}

extension View {
    func errorBanner(_ error: Binding<FocusmateError?>, onRetry: (() -> Void)? = nil) -> some View {
        modifier(ErrorBannerModifier(error: error, onRetry: onRetry))
    }

    /// Floating error banner that stays pinned to top of screen, visible regardless of scroll.
    /// Supports async retry actions.
    func floatingErrorBanner(_ error: Binding<FocusmateError?>, onRetry: (() async -> Void)? = nil) -> some View {
        modifier(FloatingErrorBannerModifier(error: error, onRetry: onRetry))
    }
}
