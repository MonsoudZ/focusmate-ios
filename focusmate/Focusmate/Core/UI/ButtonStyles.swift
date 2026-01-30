import SwiftUI

// MARK: - Intentia Button Styles

// MARK: - Toolbar Button Styles

/// Toolbar cancel/dismiss button — clean accent text
struct IntentiaToolbarCancelStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.body)
            .foregroundStyle(DS.Colors.accent)
            .fixedSize()
            .opacity(configuration.isPressed ? 0.5 : 1.0)
    }
}

/// Toolbar primary action button — bold accent text
struct IntentiaToolbarPrimaryStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.bodyMedium)
            .foregroundStyle(isEnabled ? DS.Colors.accent : DS.Colors.accent.opacity(0.4))
            .fixedSize()
            .opacity(configuration.isPressed ? 0.5 : 1.0)
    }
}

// MARK: - Full Width Button Styles

/// Primary action button — accent gradient, rounded, prominent shadow
struct IntentiaPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, DS.Spacing.xxl)
            .padding(.vertical, DS.Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: isEnabled
                        ? [DS.Colors.accent.opacity(0.9), DS.Colors.accent, DS.Colors.accent.opacity(0.85)]
                        : [Color.gray.opacity(0.4), Color.gray.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .shadow(
                color: isEnabled ? DS.Shadow.glow.color : .clear,
                radius: DS.Shadow.glow.radius,
                y: DS.Shadow.glow.y
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(DS.Anim.quick, value: configuration.isPressed)
    }
}

/// Secondary button — soft accent tint background, rounded
struct IntentiaSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.headline)
            .foregroundStyle(isEnabled ? DS.Colors.accent : .secondary)
            .padding(.horizontal, DS.Spacing.xxl)
            .padding(.vertical, DS.Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(
                (isEnabled ? DS.Colors.accent : Color.gray).opacity(0.12)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.75 : 1.0)
            .animation(DS.Anim.quick, value: configuration.isPressed)
    }
}

/// Card button — subtle press effect with scale + opacity for tappable cards
struct IntentiaCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(DS.Anim.quick, value: configuration.isPressed)
    }
}
