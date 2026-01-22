import SwiftUI

// MARK: - Design System (Apple-Aligned)
//
// Philosophy: Use Apple's semantic colors and typography wherever possible.
// Only define tokens for things Apple doesn't provide (spacing, radii, brand colors).

enum DS {
    
    // MARK: - Brand & Semantic Colors
    //
    // Apple provides: Color.primary, Color.secondary, Color(.systemBackground),
    // Color(.secondarySystemBackground), Color(.separator), etc.
    //
    // We only define: brand accent, semantic states
    
    enum Colors {
        // Brand
        static let accent = Color.blue  // Or use Color("AccentColor") from assets
        
        // Semantic states (task-specific)
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let overdue = Color.red
        
        // Time of day icons
        static let morning = Color.orange
        static let afternoon = Color.yellow
        static let evening = Color.indigo
        
        // List palette
        static let listColors: [String: Color] = [
            "blue": .blue,
            "green": .green,
            "orange": .orange,
            "red": .red,
            "purple": .purple,
            "pink": .pink,
            "teal": .teal,
            "yellow": .yellow,
            "gray": .gray
        ]
        
        static let listColorOrder = ["blue", "green", "orange", "red", "purple", "pink", "teal", "yellow", "gray"]
        
        static func list(_ name: String) -> Color {
            listColors[name] ?? .blue
        }
    }
    
    // MARK: - Spacing
    //
    // Apple doesn't provide spacing tokens, so we define our own.
    
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }
    
    // MARK: - Corner Radius
    
    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
    }
    
    // MARK: - Sizes
    //
    // For things that need fixed dimensions
    
    enum Size {
        static let iconSmall: CGFloat = 16
        static let iconMedium: CGFloat = 20
        static let iconLarge: CGFloat = 24
        static let iconXL: CGFloat = 32
        static let iconJumbo: CGFloat = 56
        
        static let avatarSmall: CGFloat = 32
        static let avatarMedium: CGFloat = 44
        static let avatarLarge: CGFloat = 60
        
        static let checkbox: CGFloat = 24
        static let checkboxSmall: CGFloat = 20
        static let minTapTarget: CGFloat = 44
        
        static let progressRing: CGFloat = 80
        static let progressStroke: CGFloat = 10
        
        static let colorIndicatorWidth: CGFloat = 4
    }
    
    // MARK: - SF Symbol Names
    //
    // Organized for easy reference
    
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


// MARK: - View Modifiers

extension View {
    
    /// Card background with system color
    func card(padding: CGFloat = DS.Spacing.md) -> some View {
        self
            .padding(padding)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(DS.Radius.md)
    }
    
    /// Subtle card (less prominent)
    func cardSubtle(padding: CGFloat = DS.Spacing.md) -> some View {
        self
            .padding(padding)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(DS.Radius.md)
    }
}


// MARK: - Simple Reusable Components

/// Empty state - uses system typography and colors
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
                .font(.system(size: DS.Size.iconJumbo))
                .foregroundStyle(.secondary)
            
            VStack(spacing: DS.Spacing.sm) {
                Text(title)
                    .font(.title3.weight(.semibold))
                
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DS.Spacing.xl)
    }
}

/// Avatar with initials
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
            .fill(DS.Colors.accent)
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(fontSize.weight(.semibold))
                    .foregroundStyle(.white)
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
                .font(.title3.weight(.semibold))
            
            if let count {
                Text("(\(count))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Progress ring
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
                    isComplete ? DS.Colors.success : DS.Colors.accent,
                    style: StrokeStyle(lineWidth: DS.Size.progressStroke, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: progress)
            
            if isComplete {
                Image(systemName: "checkmark")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(DS.Colors.success)
            } else {
                Text("\(Int(progress * 100))%")
                    .font(.title2.weight(.bold))
            }
        }
        .frame(width: DS.Size.progressRing, height: DS.Size.progressRing)
    }
}

/// Color indicator bar
struct ColorBar: View {
    let color: Color
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: DS.Size.colorIndicatorWidth, height: 40)
    }
}

/// Alert banner
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
                .font(.title3)
            
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(.body.weight(.semibold))
                if let message {
                    Text(message)
                        .font(.caption)
                }
            }
            
            Spacer()
        }
        .foregroundStyle(style.foreground)
        .padding(DS.Spacing.md)
        .background(style.color)
        .cornerRadius(DS.Radius.md)
    }
}

/// Color picker for lists
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
                            .stroke(Color.primary, lineWidth: selected == name ? 3 : 0)
                    )
                    .onTapGesture {
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
                    .font(.caption)
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
                Text("Avatars").font(.headline)
                HStack(spacing: DS.Spacing.md) {
                    Avatar("John Doe", size: DS.Size.avatarSmall)
                    Avatar("Jane Smith", size: DS.Size.avatarMedium)
                    Avatar("Bob", size: DS.Size.avatarLarge)
                }
            }
            
            // Progress
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Progress").font(.headline)
                HStack(spacing: DS.Spacing.xl) {
                    ProgressRing(0.33)
                    ProgressRing(0.75)
                    ProgressRing(1.0, isComplete: true)
                }
            }
            
            // Banners
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Banners").font(.headline)
                Banner("Apps Blocked", message: "Complete tasks to unlock", icon: DS.Icon.lock, style: .error)
                Banner("Grace Period", message: "2 hours remaining", icon: DS.Icon.timer, style: .warning)
            }
            
            // Section Headers
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Section Headers").font(.headline)
                SectionHeader("Overdue", icon: DS.Icon.overdue, iconColor: DS.Colors.error, count: 3)
                SectionHeader("Morning", icon: DS.Icon.morning, iconColor: DS.Colors.morning, count: 5)
            }
            
            // Cards
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Cards").font(.headline)
                Text("Card content here")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
            }
            
            // Color Picker
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("List Colors").font(.headline)
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
        print("Create tapped")
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
