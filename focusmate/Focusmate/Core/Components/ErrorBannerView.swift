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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
                
                Text(error.title)
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            
            Text(error.message)
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            
            if error.isRetryable, let onRetry {
                Button {
                    onRetry()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(.subheadline.weight(.medium))
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    private var iconName: String {
        switch error.code {
        case "NO_INTERNET", "NETWORK_ERROR":
            return "wifi.slash"
        case "UNAUTHORIZED":
            return "lock"
        case "NOT_FOUND":
            return "magnifyingglass"
        case "TIMEOUT":
            return "clock"
        case "RATE_LIMITED":
            return "hand.raised"
        default:
            return "exclamationmark.triangle"
        }
    }
    
    private var iconColor: Color {
        switch error.code {
        case "UNAUTHORIZED", "NOT_FOUND":
            return .orange
        case _ where error.code.hasPrefix("SERVER_ERROR"):
            return .red
        default:
            return .red
        }
    }
    
    private var backgroundColor: Color {
        Color.red.opacity(0.1)
    }
    
    private var borderColor: Color {
        Color.red.opacity(0.3)
    }
}

// MARK: - View Modifier for easy use

struct ErrorBannerModifier: ViewModifier {
    @Binding var error: FocusmateError?
    let onRetry: (() -> Void)?
    
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            
            if let error {
                ErrorBannerView(
                    error: error,
                    onDismiss: { self.error = nil },
                    onRetry: onRetry
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
                .padding(.top, 8)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: error != nil)
    }
}

extension View {
    func errorBanner(_ error: Binding<FocusmateError?>, onRetry: (() -> Void)? = nil) -> some View {
        modifier(ErrorBannerModifier(error: error, onRetry: onRetry))
    }
}
