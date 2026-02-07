import SwiftUI

/// Toast overlay for task detail view
struct TaskDetailToastOverlay: View {
    let showNudgeSent: Bool
    let showCopied: Bool

    var body: some View {
        if showNudgeSent {
            ToastView(icon: "hand.point.right.fill", message: "Nudge sent!")
        } else if showCopied {
            ToastView(icon: "doc.on.doc.fill", message: "Link copied!")
        }
    }
}

// MARK: - Toast View

private struct ToastView: View {
    let icon: String
    let message: String

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
            Text(message)
                .font(DS.Typography.bodyMedium)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Colors.success)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .padding(.top, DS.Spacing.md)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
