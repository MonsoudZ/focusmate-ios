import SwiftUI

// MARK: - Quick Date Pill

/// Modern pill-style quick date selector with icon
///
/// Design concept: This is a **radio button group** pattern - only one can be
/// selected at a time, and selection is visually distinct through color/scale.
struct QuickDatePill: View {
  let title: String
  let icon: String
  let isSelected: Bool
  let action: () -> Void

  init(_ title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) {
    self.title = title
    self.icon = icon
    self.isSelected = isSelected
    self.action = action
  }

  var body: some View {
    Button {
      HapticManager.selection()
      self.action()
    } label: {
      HStack(spacing: DS.Spacing.xs) {
        Image(systemName: self.icon)
          .font(.caption)
        Text(self.title)
          .font(DS.Typography.caption)
      }
      .padding(.horizontal, DS.Spacing.md)
      .padding(.vertical, DS.Spacing.sm)
      .background(self.isSelected ? DS.Colors.accent : Color(.tertiarySystemBackground))
      .foregroundStyle(self.isSelected ? .white : .primary)
      .clipShape(Capsule())
      .overlay(
        Capsule()
          .stroke(self.isSelected ? DS.Colors.accent : Color.clear, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .scaleEffect(self.isSelected ? 1.02 : 1.0)
    .animateIfAllowed(DS.Anim.quick, value: self.isSelected)
    .accessibilityLabel("\(self.title)\(self.isSelected ? ", selected" : "")")
    .accessibilityAddTraits(self.isSelected ? .isSelected : [])
  }
}

// MARK: - Priority Picker

/// Horizontal visual priority picker
struct PriorityPicker: View {
  @Binding var selected: TaskPriority

  var body: some View {
    HStack(spacing: DS.Spacing.sm) {
      ForEach(TaskPriority.allCases, id: \.self) { priority in
        PriorityOption(
          priority: priority,
          isSelected: self.selected == priority
        ) {
          HapticManager.selection()
          self.selected = priority
        }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Priority selector")
  }
}

struct PriorityOption: View {
  let priority: TaskPriority
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: self.action) {
      VStack(spacing: DS.Spacing.xs) {
        ZStack {
          Circle()
            .fill(self.isSelected ? self.priority.color
              .opacity(DS.Opacity.tintBackgroundActive) : Color(.tertiarySystemBackground))
            .frame(width: 44, height: 44)

          if let icon = priority.icon {
            Image(systemName: icon)
              .scaledFont(size: 18, relativeTo: .body)
              .foregroundStyle(self.priority.color)
          } else {
            Image(systemName: "minus")
              .scaledFont(size: 18, relativeTo: .body)
              .foregroundStyle(.secondary)
          }
        }
        .overlay(
          Circle()
            .stroke(self.isSelected ? self.priority.color : Color.clear, lineWidth: 2)
        )
        .scaleEffect(self.isSelected ? 1.1 : 1.0)

        Text(self.priority.label)
          .font(DS.Typography.caption)
          .foregroundStyle(self.isSelected ? self.priority.color : .secondary)
      }
    }
    .buttonStyle(.plain)
    .animateIfAllowed(DS.Anim.quick, value: self.isSelected)
    .accessibilityLabel("\(self.priority.label) priority\(self.isSelected ? ", selected" : "")")
    .accessibilityAddTraits(self.isSelected ? .isSelected : [])
  }
}

// MARK: - Starred Row

/// Animated starred toggle row
struct StarredRow: View {
  @Binding var isStarred: Bool

  var body: some View {
    Button {
      HapticManager.selection()
      withMotionAnimation(DS.Anim.quick) {
        self.isStarred.toggle()
      }
    } label: {
      HStack {
        Image(systemName: self.isStarred ? DS.Icon.starFilled : DS.Icon.star)
          .scaledFont(size: 22, relativeTo: .title2)
          .foregroundStyle(self.isStarred ? .yellow : .secondary)
          .scaleEffect(self.isStarred ? 1.2 : 1.0)
          .animateIfAllowed(.spring(duration: 0.3, bounce: 0.5), value: self.isStarred)

        Text("Starred")
          .font(DS.Typography.body)
          .foregroundStyle(.primary)

        Spacer()

        if self.isStarred {
          Text("Important")
            .font(DS.Typography.caption)
            .foregroundStyle(.secondary)
            .transition(.opacity.combined(with: .scale))
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Starred: \(self.isStarred ? "on" : "off")")
    .accessibilityHint("Double tap to toggle")
  }
}

// MARK: - Task Color Picker

/// Modern color picker with scale animation
struct TaskColorPicker: View {
  @Binding var selected: String?

  var body: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: DS.Spacing.md) {
      // "None" option
      Button {
        HapticManager.selection()
        self.selected = nil
      } label: {
        Circle()
          .fill(Color(.tertiarySystemBackground))
          .frame(width: 36, height: 36)
          .overlay(
            Image(systemName: "xmark")
              .font(.caption)
              .foregroundStyle(.secondary)
          )
          .overlay(
            Circle()
              .stroke(self.selected == nil ? DS.Colors.accent : Color.clear, lineWidth: 2)
              .padding(-2)
          )
          .scaleEffect(self.selected == nil ? 1.1 : 1.0)
      }
      .buttonStyle(.plain)
      .animateIfAllowed(DS.Anim.quick, value: self.selected)
      .accessibilityLabel("No color\(self.selected == nil ? ", selected" : "")")

      ForEach(DS.Colors.listColorOrder, id: \.self) { name in
        Button {
          HapticManager.selection()
          self.selected = name
        } label: {
          Circle()
            .fill(DS.Colors.list(name))
            .frame(width: 36, height: 36)
            .overlay(
              Circle()
                .stroke(DS.Colors.accent, lineWidth: self.selected == name ? 2 : 0)
                .padding(-2)
            )
            .overlay(
              Image(systemName: "checkmark")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .opacity(self.selected == name ? 1 : 0)
            )
            .scaleEffect(self.selected == name ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .animateIfAllowed(DS.Anim.quick, value: self.selected)
        .accessibilityLabel("\(name) color\(self.selected == name ? ", selected" : "")")
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Color picker")
  }
}

// MARK: - Weekday Picker

struct WeekdayPicker: View {
  @Binding var selectedDays: Set<Int>

  private let days = [(0, "S"), (1, "M"), (2, "T"), (3, "W"), (4, "T"), (5, "F"), (6, "S")]
  private let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

  var body: some View {
    HStack(spacing: DS.Spacing.sm) {
      ForEach(self.days, id: \.0) { day, label in
        Button {
          HapticManager.selection()
          if self.selectedDays.contains(day) {
            if self.selectedDays.count > 1 {
              self.selectedDays.remove(day)
            }
          } else {
            self.selectedDays.insert(day)
          }
        } label: {
          Text(label)
            .font(.caption.bold())
            .frame(width: 32, height: 32)
            .background(self.selectedDays.contains(day) ? DS.Colors.accent : Color(.secondarySystemBackground))
            .foregroundStyle(self.selectedDays.contains(day) ? .white : .primary)
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(self.dayNames[day])\(self.selectedDays.contains(day) ? ", selected" : "")")
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Weekday picker")
  }
}

// MARK: - Recurrence Pattern Enum

enum RecurrencePattern: String, CaseIterable {
  case none = ""
  case daily
  case weekly
  case monthly
  case yearly

  var label: String {
    switch self {
    case .none: return "Never"
    case .daily: return "Daily"
    case .weekly: return "Weekly"
    case .monthly: return "Monthly"
    case .yearly: return "Yearly"
    }
  }
}
