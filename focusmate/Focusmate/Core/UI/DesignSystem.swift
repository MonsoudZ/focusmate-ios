import SwiftUI

enum DesignSystem {

    // MARK: - Colors

    enum Colors {
        static let primary = Color.blue
        static let primaryLight = Color.blue.opacity(0.1)

        static let success = Color.green
        static let successLight = Color.green.opacity(0.1)

        static let warning = Color.orange
        static let warningLight = Color.orange.opacity(0.1)

        static let error = Color.red
        static let errorLight = Color.red.opacity(0.1)

        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemBackground)
        static let groupedBackground = Color(.systemGroupedBackground)
        static let cardBackground = Color(.systemGray6)

        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary

        static let overdue = Color.red
        static let completed = Color.green

        static let border = Color(.separator)
    }

    // MARK: - Typography

    enum Typography {
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title1 = Font.title.weight(.bold)
        static let title2 = Font.title2.weight(.bold)
        static let title3 = Font.title3.weight(.semibold)

        static let body = Font.body
        static let bodyEmphasized = Font.body.weight(.semibold)
        static let callout = Font.callout
        static let subheadline = Font.subheadline

        static let caption1 = Font.caption
        static let caption2 = Font.caption2
        static let footnote = Font.footnote

        static let buttonLabel = Font.body.weight(.semibold)
        static let cardTitle = Font.headline
        static let sectionHeader = Font.subheadline.weight(.semibold)
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

        static let padding = lg
        static let cardPadding = md
        static let sectionSpacing = xl
        static let itemSpacing = sm
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16

        static let card = md
        static let button = md
    }

    // MARK: - Shadows

    enum Shadow {
        static let small = (color: Color.black.opacity(0.1), radius: CGFloat(2), x: CGFloat(0), y: CGFloat(1))
        static let medium = (color: Color.black.opacity(0.1), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
    }

    // MARK: - Animation

    enum Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
    }

    // MARK: - Icons

    enum Icons {
        static let task = "circle"
        static let taskCompleted = "checkmark.circle.fill"
        static let taskOverdue = "exclamationmark.triangle.fill"

        static let list = "list.bullet"

        static let add = "plus"
        static let edit = "pencil"
        static let delete = "trash"

        static let loading = "hourglass"
        static let error = "exclamationmark.triangle"
        static let empty = "tray"
        static let success = "checkmark.circle.fill"

        static let settings = "gear"
        static let profile = "person.circle"

        static let calendar = "calendar"
        static let time = "clock"
    }
}

// MARK: - View Extensions

extension View {
    func cardStyle() -> some View {
        self
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.card)
            .shadow(
                color: DesignSystem.Shadow.small.color,
                radius: DesignSystem.Shadow.small.radius,
                x: DesignSystem.Shadow.small.x,
                y: DesignSystem.Shadow.small.y
            )
    }

    func badgeStyle(color: Color) -> some View {
        self
            .font(DesignSystem.Typography.caption2)
            .foregroundColor(color)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    func sectionHeaderStyle() -> some View {
        self
            .font(DesignSystem.Typography.sectionHeader)
            .foregroundColor(DesignSystem.Colors.textSecondary)
            .textCase(.uppercase)
    }
}

// MARK: - Components

struct DSCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(DesignSystem.Spacing.cardPadding)
            .cardStyle()
    }
}

struct DSBadge: View {
    let text: String
    let icon: String?
    let color: Color

    init(_ text: String, icon: String? = nil, color: Color = DesignSystem.Colors.primary) {
        self.text = text
        self.icon = icon
        self.color = color
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xxs) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(DesignSystem.Typography.caption2)
            }
            Text(text)
                .font(DesignSystem.Typography.caption2)
        }
        .badgeStyle(color: color)
    }
}

struct DSSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .sectionHeaderStyle()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignSystem.Spacing.padding)
            .padding(.vertical, DesignSystem.Spacing.xs)
    }
}
