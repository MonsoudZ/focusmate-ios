import SwiftUI

// MARK: - Intentia Design System Tokens

//
// Soft, rounded, modern iOS aesthetic with accountability as a central visual identity.
// Inspired by Apple Health/Fitness apps.
//
// Brand: Intentia — intentional, calm authority, soft accountability
// Style: Generous radii, gentle shadows, warm palette, SF Rounded headings

enum DS {
  // MARK: - Brand & Semantic Colors

  enum Colors {
    /// Brand accent — deep blue
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

    /// List palette — softer/warmer variants
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
      self.listColors[name] ?? Color(light: 0x2563EB, dark: 0x3B82F6)
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
    static let xs: CGFloat = 8 // pills, small badges
    static let sm: CGFloat = 12 // tags, chips, small cards
    static let md: CGFloat = 16 // standard cards, task rows
    static let lg: CGFloat = 20 // large cards, sheets
    static let xl: CGFloat = 24 // hero cards, modals
    static let full: CGFloat = 999 // circles, capsules
  }

  // MARK: - Opacity

  enum Opacity {
    /// Tag pills, priority badges, status indicators
    static let tintBackground: CGFloat = 0.15
    /// Selected tags, active priority buttons
    static let tintBackgroundActive: CGFloat = 0.2
  }

  // MARK: - Shadows

  enum Shadow {
    static let sm = (color: Color.black.opacity(0.08), radius: CGFloat(6), y: CGFloat(3))
    static let md = (color: Color.black.opacity(0.12), radius: CGFloat(12), y: CGFloat(5))
    static let lg = (color: Color.black.opacity(0.16), radius: CGFloat(20), y: CGFloat(8))
    /// Colored shadow for accent elements
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

    static let checkbox: CGFloat = 26 // slightly larger for better tap
    static let checkboxSmall: CGFloat = 20
    static let minTapTarget: CGFloat = 44

    static let progressRing: CGFloat = 88 // slightly larger for visual impact
    static let progressStroke: CGFloat = 8 // thinner for modern feel

    static let colorIndicatorWidth: CGFloat = 5 // slightly thicker
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
