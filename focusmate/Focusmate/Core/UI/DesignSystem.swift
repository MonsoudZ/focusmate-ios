import SwiftUI

// MARK: - Design System

/// Central design system for consistent UI across the app
enum DesignSystem {

  // MARK: - Colors

  enum Colors {
    // Primary brand colors
    static let primary = Color.blue
    static let primaryLight = Color.blue.opacity(0.1)

    // Semantic colors
    static let success = Color.green
    static let successLight = Color.green.opacity(0.1)

    static let warning = Color.orange
    static let warningLight = Color.orange.opacity(0.1)

    static let error = Color.red
    static let errorLight = Color.red.opacity(0.1)

    static let info = Color.blue
    static let infoLight = Color.blue.opacity(0.1)

    // UI colors
    static let background = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    static let tertiaryBackground = Color(.tertiarySystemBackground)
    static let groupedBackground = Color(.systemGroupedBackground)
    static let cardBackground = Color(.systemGray6)

    // Text colors
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(.tertiaryLabel)

    // Feature-specific colors
    static let recurring = Color.blue
    static let recurringLight = Color.blue.opacity(0.1)

    static let location = Color.purple
    static let locationLight = Color.purple.opacity(0.1)

    static let overdue = Color.red
    static let overdueLight = Color.red.opacity(0.1)

    static let completed = Color.green
    static let completedLight = Color.green.opacity(0.1)

    // Borders and separators
    static let border = Color(.separator)
    static let borderLight = Color(.separator).opacity(0.5)
  }

  // MARK: - Typography

  enum Typography {
    // Headings
    static let largeTitle = Font.largeTitle.weight(.bold)
    static let title1 = Font.title.weight(.bold)
    static let title2 = Font.title2.weight(.bold)
    static let title3 = Font.title3.weight(.semibold)

    // Body text
    static let body = Font.body
    static let bodyEmphasized = Font.body.weight(.semibold)
    static let callout = Font.callout
    static let subheadline = Font.subheadline

    // Small text
    static let caption1 = Font.caption
    static let caption2 = Font.caption2
    static let footnote = Font.footnote

    // Specialized
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
    static let xxxl: CGFloat = 48

    // Semantic spacing
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
    static let pill: CGFloat = 999

    // Semantic
    static let card = md
    static let button = md
    static let badge = pill
  }

  // MARK: - Shadows

  enum Shadow {
    static let small = (color: Color.black.opacity(0.1), radius: CGFloat(2), x: CGFloat(0), y: CGFloat(1))
    static let medium = (color: Color.black.opacity(0.1), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
    static let large = (color: Color.black.opacity(0.15), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
  }

  // MARK: - Animation

  enum Animation {
    static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
    static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
    static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)

    static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
  }

  // MARK: - Icons

  enum Icons {
    // Tasks & Items
    static let task = "circle"
    static let taskCompleted = "checkmark.circle.fill"
    static let taskOverdue = "exclamationmark.triangle.fill"
    static let taskRecurring = "repeat"
    static let taskLocation = "location.fill"
    static let taskSubtasks = "checklist"

    // Lists
    static let list = "list.bullet"
    static let listShared = "person.2"

    // Actions
    static let add = "plus"
    static let edit = "pencil"
    static let delete = "trash"
    static let share = "square.and.arrow.up"
    static let select = "checkmark.circle"
    static let move = "arrow.right"
    static let assign = "person"

    // States
    static let loading = "hourglass"
    static let error = "exclamationmark.triangle"
    static let empty = "tray"
    static let success = "checkmark.circle.fill"

    // Settings
    static let settings = "gear"
    static let profile = "person.circle"
    static let notifications = "bell"

    // Calendar & Time
    static let calendar = "calendar"
    static let time = "clock"
    static let dueDate = "calendar.badge.exclamationmark"
  }
}

// MARK: - View Extensions

extension View {
  /// Apply card styling
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

  /// Apply badge styling with custom color
  func badgeStyle(color: Color) -> some View {
    self
      .font(DesignSystem.Typography.caption2)
      .foregroundColor(color)
      .padding(.horizontal, DesignSystem.Spacing.sm)
      .padding(.vertical, DesignSystem.Spacing.xxs)
      .background(color.opacity(0.1))
      .clipShape(Capsule())
  }

  /// Apply section header styling
  func sectionHeaderStyle() -> some View {
    self
      .font(DesignSystem.Typography.sectionHeader)
      .foregroundColor(DesignSystem.Colors.textSecondary)
      .textCase(.uppercase)
  }
}

// MARK: - Custom Components

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
