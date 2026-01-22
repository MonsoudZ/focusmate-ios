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
        .cornerRadius(DS.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
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

extension View {
    func errorBanner(_ error: Binding<FocusmateError?>, onRetry: (() -> Void)? = nil) -> some View {
        modifier(ErrorBannerModifier(error: error, onRetry: onRetry))
    }
}
