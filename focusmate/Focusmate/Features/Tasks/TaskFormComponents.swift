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
            action()
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(DS.Typography.caption)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(isSelected ? DS.Colors.accent : Color(.tertiarySystemBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? DS.Colors.accent : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(DS.Anim.quick, value: isSelected)
        .accessibilityLabel("\(title)\(isSelected ? ", selected" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                    isSelected: selected == priority
                ) {
                    HapticManager.selection()
                    selected = priority
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
        Button(action: action) {
            VStack(spacing: DS.Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(isSelected ? priority.color.opacity(0.2) : Color(.tertiarySystemBackground))
                        .frame(width: 44, height: 44)

                    if let icon = priority.icon {
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundStyle(priority.color)
                    } else {
                        Image(systemName: "minus")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                }
                .overlay(
                    Circle()
                        .stroke(isSelected ? priority.color : Color.clear, lineWidth: 2)
                )
                .scaleEffect(isSelected ? 1.1 : 1.0)

                Text(priority.label)
                    .font(DS.Typography.caption)
                    .foregroundStyle(isSelected ? priority.color : .secondary)
            }
        }
        .buttonStyle(.plain)
        .animation(DS.Anim.quick, value: isSelected)
        .accessibilityLabel("\(priority.label) priority\(isSelected ? ", selected" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Starred Row

/// Animated starred toggle row
struct StarredRow: View {
    @Binding var isStarred: Bool

    var body: some View {
        Button {
            HapticManager.selection()
            withAnimation(DS.Anim.quick) {
                isStarred.toggle()
            }
        } label: {
            HStack {
                Image(systemName: isStarred ? DS.Icon.starFilled : DS.Icon.star)
                    .font(.system(size: 22))
                    .foregroundStyle(isStarred ? .yellow : .secondary)
                    .scaleEffect(isStarred ? 1.2 : 1.0)
                    .animation(.spring(duration: 0.3, bounce: 0.5), value: isStarred)

                Text("Starred")
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)

                Spacer()

                if isStarred {
                    Text("Important")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Starred: \(isStarred ? "on" : "off")")
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
                selected = nil
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
                            .stroke(selected == nil ? DS.Colors.accent : Color.clear, lineWidth: 2)
                            .padding(-2)
                    )
                    .scaleEffect(selected == nil ? 1.1 : 1.0)
            }
            .buttonStyle(.plain)
            .animation(DS.Anim.quick, value: selected)
            .accessibilityLabel("No color\(selected == nil ? ", selected" : "")")

            ForEach(DS.Colors.listColorOrder, id: \.self) { name in
                Button {
                    HapticManager.selection()
                    selected = name
                } label: {
                    Circle()
                        .fill(DS.Colors.list(name))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(DS.Colors.accent, lineWidth: selected == name ? 2 : 0)
                                .padding(-2)
                        )
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .opacity(selected == name ? 1 : 0)
                        )
                        .scaleEffect(selected == name ? 1.1 : 1.0)
                }
                .buttonStyle(.plain)
                .animation(DS.Anim.quick, value: selected)
                .accessibilityLabel("\(name) color\(selected == name ? ", selected" : "")")
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
            ForEach(days, id: \.0) { day, label in
                Button {
                    HapticManager.selection()
                    if selectedDays.contains(day) {
                        if selectedDays.count > 1 {
                            selectedDays.remove(day)
                        }
                    } else {
                        selectedDays.insert(day)
                    }
                } label: {
                    Text(label)
                        .font(.caption.bold())
                        .frame(width: 32, height: 32)
                        .background(selectedDays.contains(day) ? DS.Colors.accent : Color(.secondarySystemBackground))
                        .foregroundStyle(selectedDays.contains(day) ? .white : .primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(dayNames[day])\(selectedDays.contains(day) ? ", selected" : "")")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Weekday picker")
    }
}

// MARK: - Recurrence Pattern Enum

enum RecurrencePattern: String, CaseIterable {
    case none = ""
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"

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
