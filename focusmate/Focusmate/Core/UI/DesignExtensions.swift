import SwiftUI
import UIKit

// MARK: - Color Helpers

extension Color {
    /// Create an adaptive color from light/dark hex values
    init(light: UInt, dark: UInt) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        })
    }

    /// Create a color from a hex string (e.g., "#FF5733" or "FF5733")
    init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }

        guard hexString.count == 6,
              let hexValue = UInt(hexString, radix: 16) else {
            return nil
        }

        self.init(
            red: Double((hexValue >> 16) & 0xFF) / 255,
            green: Double((hexValue >> 8) & 0xFF) / 255,
            blue: Double(hexValue & 0xFF) / 255
        )
    }
}

extension UIColor {
    convenience init(hex: UInt) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}


// MARK: - View Modifiers

extension View {

    /// Conditionally apply a modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Card background with shadow and continuous corners
    func card(padding: CGFloat = DS.Spacing.md) -> some View {
        self
            .padding(padding)
            .background(DS.Colors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .shadow(color: DS.Shadow.md.color, radius: DS.Shadow.md.radius, y: DS.Shadow.md.y)
    }

    /// Hero card — accent glow, elevated, larger radius
    func heroCard(padding: CGFloat = DS.Spacing.lg) -> some View {
        self
            .padding(padding)
            .background(DS.Colors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            .shadow(color: DS.Shadow.glow.color, radius: DS.Shadow.glow.radius, y: DS.Shadow.glow.y)
    }

    /// Subtle card (less prominent)
    func cardSubtle(padding: CGFloat = DS.Spacing.md) -> some View {
        self
            .padding(padding)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
    }

    /// Surface background for main scroll views
    func surfaceBackground() -> some View {
        self
            .background(DS.Colors.surface)
    }

    /// Surface background for Form/List views (hides default grouped background)
    func surfaceFormBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(DS.Colors.surface)
    }

    /// Styled form field for use outside SwiftUI Form context
    func formFieldStyle() -> some View {
        self
            .font(DS.Typography.body)
            .padding(DS.Spacing.md)
            .background(DS.Colors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
    }
}
