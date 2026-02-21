import SwiftUI

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
      Image(systemName: self.icon)
        .scaledFont(size: 64, relativeTo: .largeTitle)
        .foregroundStyle(DS.Colors.accent)

      VStack(spacing: DS.Spacing.sm) {
        Text(self.title)
          .font(DS.Typography.title3)

        Text(self.message)
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
    switch self.size {
    case ...32: return .caption
    case 33 ... 50: return .body
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
      .frame(width: self.size, height: self.size)
      .overlay(
        Text(self.initials)
          .font(self.fontSize.weight(.semibold))
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
          .foregroundStyle(self.iconColor ?? .secondary)
      }

      Text(self.title)
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
        .trim(from: 0, to: self.progress)
        .stroke(
          self.isComplete
            ? AnyShapeStyle(DS.Colors.success)
            : AnyShapeStyle(
              AngularGradient(
                colors: [DS.Colors.accent.opacity(0.6), DS.Colors.accent],
                center: .center,
                startAngle: .degrees(-90),
                endAngle: .degrees(-90 + 360 * self.progress)
              )
            ),
          style: StrokeStyle(lineWidth: DS.Size.progressStroke, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .animateIfAllowed(.easeOut(duration: 0.5), value: self.progress)

      if self.isComplete {
        Image(systemName: "checkmark")
          .font(DS.Typography.title2)
          .foregroundStyle(DS.Colors.success)
      } else {
        Text("\(Int(self.progress * 100))%")
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
      .fill(self.color)
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
      Image(systemName: self.icon)
        .font(DS.Typography.title3)

      VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
        Text(self.title)
          .font(DS.Typography.bodyMedium)
        if let message {
          Text(message)
            .font(DS.Typography.caption)
        }
      }

      Spacer()
    }
    .foregroundStyle(self.style.useMaterial ? .primary : self.style.foreground)
    .padding(DS.Spacing.md)
    .background {
      if self.style.useMaterial {
        RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
          .fill(.ultraThinMaterial)
          .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
              .fill(self.style.color.opacity(DS.Opacity.tintBackground))
          )
      } else {
        RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
          .fill(self.style.color)
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
              .stroke(DS.Colors.accent, lineWidth: self.selected == name ? 3 : 0)
              .padding(-3)
          )
          .scaleEffect(self.selected == name ? 1.1 : 1.0)
          .animateIfAllowed(DS.Anim.quick, value: self.selected)
          .onTapGesture {
            HapticManager.selection()
            self.selected = name
          }
      }
    }
  }
}

/// Offline banner — shows connectivity status and pending mutation count
struct OfflineBanner: View {
  let isConnected: Bool
  let pendingCount: Int

  var body: some View {
    if !self.isConnected || self.pendingCount > 0 {
      HStack(spacing: DS.Spacing.sm) {
        Image(systemName: self.isConnected ? "arrow.triangle.2.circlepath" : "wifi.slash")
          .font(DS.Typography.bodyMedium)

        if !self.isConnected, self.pendingCount > 0 {
          Text("Offline — \(self.pendingCount) \(self.pendingCount == 1 ? "change" : "changes") pending")
            .font(DS.Typography.bodyMedium)
        } else if !self.isConnected {
          Text("Offline")
            .font(DS.Typography.bodyMedium)
        } else {
          Text("Syncing \(self.pendingCount) \(self.pendingCount == 1 ? "change" : "changes")…")
            .font(DS.Typography.bodyMedium)
        }

        Spacer()
      }
      .foregroundStyle(.white)
      .padding(DS.Spacing.sm)
      .padding(.horizontal, DS.Spacing.xs)
      .background(
        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
          .fill(self.isConnected ? DS.Colors.accent : Color(.systemGray))
      )
      .padding(.horizontal, DS.Spacing.md)
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
        self.line
        Text(text)
          .font(DS.Typography.caption)
          .foregroundStyle(.secondary)
        self.line
      }
    } else {
      self.line
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
