import SwiftUI
import UIKit

// MARK: - Intentia Design System
//
// Soft, rounded, modern iOS aesthetic with accountability as a central visual identity.
// Inspired by Apple Health/Fitness apps.
//
// Brand: Intentia — intentional, calm authority, soft accountability
// Style: Generous radii, gentle shadows, warm palette, SF Rounded headings

enum DS {

    // MARK: - Brand & Semantic Colors

    enum Colors {
        // Brand accent — deep blue
        static let accent = Color("AccentColor")

        // Semantic states (warmer, softer than raw system colors)
        static let success = Color(light: 0x10B981, dark: 0x34D399)
        static let warning = Color(light: 0xF59E0B, dark: 0xFBBF24)
        static let error = Color(light: 0xEF4444, dark: 0xF87171)
        static let overdue = error

        // Time of day
        static let morning = Color(light: 0xFB923C, dark: 0xFDBA74)
        static let afternoon = Color(light: 0xFBBF24, dark: 0xFDE68A)
        static let evening = Color(light: 0x8B5CF6, dark: 0xA78BFA)

        // Surface colors — faint blue tint
        static let surface = Color(light: 0xF5F7FB, dark: 0x151928)
        static let surfaceElevated = Color(light: 0xFFFFFF, dark: 0x1E2236)

        // List palette — softer/warmer variants
        static let listColors: [String: Color] = [
            "blue": Color(light: 0x2563EB, dark: 0x3B82F6),
            "green": Color(light: 0x10B981, dark: 0x34D399),
            "orange": Color(light: 0xFB923C, dark: 0xFDBA74),
            "red": Color(light: 0xEF4444, dark: 0xF87171),
            "purple": Color(light: 0x8B5CF6, dark: 0xA78BFA),
            "pink": Color(light: 0xEC4899, dark: 0xF472B6),
            "teal": Color(light: 0x14B8A6, dark: 0x2DD4BF),
            "yellow": Color(light: 0xF59E0B, dark: 0xFBBF24),
            "gray": Color(light: 0x6B7280, dark: 0x9CA3AF),
        ]

        static let listColorOrder = ["blue", "green", "orange", "red", "purple", "pink", "teal", "yellow", "gray"]

        static func list(_ name: String) -> Color {
            listColors[name] ?? Color(light: 0x2563EB, dark: 0x3B82F6)
        }
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 40
    }

    // MARK: - Corner Radius (larger, continuous)

    enum Radius {
        static let xs: CGFloat = 8      // pills, small badges
        static let sm: CGFloat = 12     // tags, chips, small cards
        static let md: CGFloat = 16     // standard cards, task rows
        static let lg: CGFloat = 20     // large cards, sheets
        static let xl: CGFloat = 24     // hero cards, modals
        static let full: CGFloat = 999  // circles, capsules
    }

    // MARK: - Shadows

    enum Shadow {
        static let sm = (color: Color.black.opacity(0.08), radius: CGFloat(6), y: CGFloat(3))
        static let md = (color: Color.black.opacity(0.12), radius: CGFloat(12), y: CGFloat(5))
        static let lg = (color: Color.black.opacity(0.16), radius: CGFloat(20), y: CGFloat(8))
        // Colored shadow for accent elements
        static let glow = (color: DS.Colors.accent.opacity(0.35), radius: CGFloat(16), y: CGFloat(6))
    }

    // MARK: - Typography (SF Rounded for headings)

    enum Typography {
        static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
        static let title1 = Font.system(.title, design: .rounded, weight: .bold)
        static let title2 = Font.system(.title2, design: .rounded, weight: .semibold)
        static let title3 = Font.system(.title3, design: .rounded, weight: .semibold)
        static let headline = Font.system(.headline, design: .rounded, weight: .semibold)
        static let body = Font.system(.body)
        static let bodyMedium = Font.system(.body, weight: .medium)
        static let callout = Font.system(.callout)
        static let subheadline = Font.system(.subheadline)
        static let footnote = Font.system(.footnote)
        static let caption = Font.system(.caption)
        static let caption2 = Font.system(.caption2)
    }

    // MARK: - Animation Tokens

    enum Anim {
        static let quick = SwiftUI.Animation.spring(duration: 0.2, bounce: 0.1)
        static let normal = SwiftUI.Animation.spring(duration: 0.35, bounce: 0.15)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.3)
    }

    // MARK: - Sizes

    enum Size {
        static let iconSmall: CGFloat = 16
        static let iconMedium: CGFloat = 20
        static let iconLarge: CGFloat = 24
        static let iconXL: CGFloat = 32
        static let iconJumbo: CGFloat = 56
        static let logo: CGFloat = 80

        static let avatarSmall: CGFloat = 32
        static let avatarMedium: CGFloat = 44
        static let avatarLarge: CGFloat = 60

        static let checkbox: CGFloat = 26       // slightly larger for better tap
        static let checkboxSmall: CGFloat = 20
        static let minTapTarget: CGFloat = 44

        static let progressRing: CGFloat = 88   // slightly larger for visual impact
        static let progressStroke: CGFloat = 8   // thinner for modern feel

        static let colorIndicatorWidth: CGFloat = 5  // slightly thicker
    }

    // MARK: - SF Symbol Names

    enum Icon {
        // Tasks
        static let circle = "circle"
        static let circleChecked = "checkmark.circle.fill"
        static let overdue = "exclamationmark.triangle.fill"
        static let subtasks = "checklist"
        static let star = "star"
        static let starFilled = "star.fill"
        static let recurring = "repeat"

        // Time
        static let clock = "clock"
        static let calendar = "calendar"
        static let morning = "sunrise.fill"
        static let afternoon = "sun.max.fill"
        static let evening = "moon.fill"

        // Actions
        static let plus = "plus"
        static let edit = "pencil"
        static let trash = "trash"
        static let search = "magnifyingglass"
        static let share = "person.2"

        // Navigation
        static let chevronRight = "chevron.right"
        static let chevronDown = "chevron.down"
        static let chevronUp = "chevron.up"
        static let back = "chevron.left"
        static let close = "xmark"
        static let externalLink = "arrow.up.right"

        // Status
        static let lock = "lock.fill"
        static let timer = "timer"
        static let bell = "bell"
        static let shield = "shield"
        static let info = "info.circle"
        static let checkSeal = "checkmark.seal.fill"

        // Empty states
        static let emptyTray = "tray"
        static let emptyList = "list.bullet"
    }
}


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

private extension UIColor {
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


// MARK: - Simple Reusable Components

/// Empty state — accent-tinted icon, rounded typography
struct EmptyState: View {
    let title: String
    let message: String
    let icon: String
    let action: (() -> Void)?
    let actionTitle: String?

    init(
        _ title: String,
        message: String,
        icon: String = DS.Icon.emptyTray,
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
        VStack(spacing: DS.Spacing.xl) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(DS.Colors.accent)

            VStack(spacing: DS.Spacing.sm) {
                Text(title)
                    .font(DS.Typography.title3)

                Text(message)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(DS.Typography.bodyMedium)
                }
                .buttonStyle(IntentiaPrimaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DS.Spacing.xl)
    }
}

/// Avatar with gradient background
struct Avatar: View {
    let name: String?
    let size: CGFloat

    init(_ name: String?, size: CGFloat = DS.Size.avatarMedium) {
        self.name = name
        self.size = size
    }

    private var initials: String {
        guard let name, !name.isEmpty else { return "?" }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return name.prefix(2).uppercased()
    }

    private var fontSize: Font {
        switch size {
        case ...32: return .caption
        case 33...50: return .body
        default: return .title2
        }
    }

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [DS.Colors.accent.opacity(0.8), DS.Colors.accent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(fontSize.weight(.semibold))
                    .foregroundStyle(.white)
            )
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.3), lineWidth: 1.5)
            )
    }
}

/// Section header for lists
struct SectionHeader: View {
    let title: String
    let icon: String?
    let iconColor: Color?
    let count: Int?

    init(_ title: String, icon: String? = nil, iconColor: Color? = nil, count: Int? = nil) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.count = count
    }

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(iconColor ?? .secondary)
            }

            Text(title)
                .font(DS.Typography.title3)

            if let count {
                Text("(\(count))")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Progress ring — gradient stroke
struct ProgressRing: View {
    let progress: Double
    let isComplete: Bool

    init(_ progress: Double, isComplete: Bool = false) {
        self.progress = progress
        self.isComplete = isComplete
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: DS.Size.progressStroke)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    isComplete
                        ? AnyShapeStyle(DS.Colors.success)
                        : AnyShapeStyle(
                            AngularGradient(
                                colors: [DS.Colors.accent.opacity(0.6), DS.Colors.accent],
                                center: .center,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(-90 + 360 * progress)
                            )
                        ),
                    style: StrokeStyle(lineWidth: DS.Size.progressStroke, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: progress)

            if isComplete {
                Image(systemName: "checkmark")
                    .font(DS.Typography.title2)
                    .foregroundStyle(DS.Colors.success)
            } else {
                Text("\(Int(progress * 100))%")
                    .font(DS.Typography.title2)
            }
        }
        .frame(width: DS.Size.progressRing, height: DS.Size.progressRing)
    }
}

/// Color indicator bar — capsule shape
struct ColorBar: View {
    let color: Color

    var body: some View {
        Capsule()
            .fill(color)
            .frame(width: DS.Size.colorIndicatorWidth, height: 40)
    }
}

/// Alert banner — material backgrounds for info/warning, solid for error
struct Banner: View {
    let title: String
    let message: String?
    let icon: String
    let style: Style

    enum Style {
        case info, warning, error, success

        var color: Color {
            switch self {
            case .info: return DS.Colors.accent
            case .warning: return DS.Colors.warning
            case .error: return DS.Colors.error
            case .success: return DS.Colors.success
            }
        }

        var foreground: Color {
            self == .warning ? .black : .white
        }

        var useMaterial: Bool {
            switch self {
            case .info, .warning: return true
            case .error, .success: return false
            }
        }
    }

    init(_ title: String, message: String? = nil, icon: String, style: Style) {
        self.title = title
        self.message = message
        self.icon = icon
        self.style = style
    }

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(DS.Typography.title3)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Typography.bodyMedium)
                if let message {
                    Text(message)
                        .font(DS.Typography.caption)
                }
            }

            Spacer()
        }
        .foregroundStyle(style.useMaterial ? .primary : style.foreground)
        .padding(DS.Spacing.md)
        .background {
            if style.useMaterial {
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                            .fill(style.color.opacity(0.15))
                    )
            } else {
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(style.color)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
    }
}

/// Color picker for lists — accent selection ring
struct ListColorPicker: View {
    @Binding var selected: String

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: DS.Spacing.md) {
            ForEach(DS.Colors.listColorOrder, id: \.self) { name in
                Circle()
                    .fill(DS.Colors.list(name))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(DS.Colors.accent, lineWidth: selected == name ? 3 : 0)
                            .padding(-3)
                    )
                    .scaleEffect(selected == name ? 1.1 : 1.0)
                    .animation(DS.Anim.quick, value: selected)
                    .onTapGesture {
                        HapticManager.selection()
                        selected = name
                    }
            }
        }
    }
}

/// Divider with optional centered text
struct DSDivider: View {
    let text: String?

    init(_ text: String? = nil) {
        self.text = text
    }

    var body: some View {
        if let text {
            HStack(spacing: DS.Spacing.md) {
                line
                Text(text)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                line
            }
        } else {
            line
        }
    }

    private var line: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(height: 1)
    }
}


// MARK: - Preview Catalog

#Preview("Components") {
    ScrollView {
        VStack(alignment: .leading, spacing: DS.Spacing.xxl) {

            // Avatars
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Avatars").font(DS.Typography.headline)
                HStack(spacing: DS.Spacing.md) {
                    Avatar("John Doe", size: DS.Size.avatarSmall)
                    Avatar("Jane Smith", size: DS.Size.avatarMedium)
                    Avatar("Bob", size: DS.Size.avatarLarge)
                }
            }

            // Progress
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Progress").font(DS.Typography.headline)
                HStack(spacing: DS.Spacing.xl) {
                    ProgressRing(0.33)
                    ProgressRing(0.75)
                    ProgressRing(1.0, isComplete: true)
                }
            }

            // Banners
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Banners").font(DS.Typography.headline)
                Banner("Apps Blocked", message: "Complete tasks to unlock", icon: DS.Icon.lock, style: .error)
                Banner("Grace Period", message: "2 hours remaining", icon: DS.Icon.timer, style: .warning)
            }

            // Section Headers
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Section Headers").font(DS.Typography.headline)
                SectionHeader("Overdue", icon: DS.Icon.overdue, iconColor: DS.Colors.error, count: 3)
                SectionHeader("Morning", icon: DS.Icon.morning, iconColor: DS.Colors.morning, count: 5)
            }

            // Cards
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Cards").font(DS.Typography.headline)
                Text("Card content here")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
            }

            // Color Picker
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("List Colors").font(DS.Typography.headline)
                ListColorPicker(selected: .constant("blue"))
            }
        }
        .padding(DS.Spacing.lg)
    }
}

#Preview("Empty State") {
    EmptyState(
        "No Lists Yet",
        message: "Create a list to organize your tasks",
        icon: DS.Icon.emptyList,
        actionTitle: "Create List"
    ) {
        // Preview placeholder - no action needed
    }
}

#Preview("Dark Mode") {
    ScrollView {
        VStack(spacing: DS.Spacing.lg) {
            Text("Card on background")
                .card()

            Banner("Warning", icon: DS.Icon.timer, style: .warning)

            ProgressRing(0.6)
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
