import SwiftUI

// MARK: - Accessibility Helpers

/// Accessibility labels and helpers for improved VoiceOver support
enum Accessibility {

  // MARK: - Task/Item Accessibility

  static func taskLabel(
    title: String,
    isCompleted: Bool,
    dueDate: Date?,
    isOverdue: Bool,
    hasSubtasks: Bool = false,
    subtasksCompleted: Int = 0,
    subtasksTotal: Int = 0
  ) -> String {
    var label = title

    if isCompleted {
      label += ", completed"
    }

    if let dueDate = dueDate {
      let dateFormatter = DateFormatter()
      dateFormatter.dateStyle = .medium
      dateFormatter.timeStyle = .short
      let dateString = dateFormatter.string(from: dueDate)

      if isOverdue && !isCompleted {
        label += ", overdue since \(dateString)"
      } else {
        label += ", due \(dateString)"
      }
    }

    if hasSubtasks {
      label += ", has \(subtasksCompleted) of \(subtasksTotal) subtasks completed"
    }

    return label
  }

  static func taskHint(isCompleted: Bool, isSelectionMode: Bool) -> String {
    if isSelectionMode {
      return "Double tap to select or deselect this task"
    } else if isCompleted {
      return "Double tap to mark as incomplete. Swipe for more options."
    } else {
      return "Double tap to mark as complete. Swipe for more options."
    }
  }

  // MARK: - List Accessibility

  static func listLabel(
    title: String,
    tasksCount: Int,
    sharedCount: Int = 0
  ) -> String {
    var label = title

    if tasksCount == 0 {
      label += ", no tasks"
    } else if tasksCount == 1 {
      label += ", 1 task"
    } else {
      label += ", \(tasksCount) tasks"
    }

    if sharedCount > 0 {
      label += ", shared with \(sharedCount) \(sharedCount == 1 ? "person" : "people")"
    }

    return label
  }

  static func listHint() -> String {
    return "Double tap to view tasks. Swipe for more options."
  }

  // MARK: - Button Accessibility

  static func buttonLabel(_ action: String, count: Int? = nil) -> String {
    if let count = count {
      return "\(action) \(count) \(count == 1 ? "item" : "items")"
    }
    return action
  }

  static func buttonHint(_ action: String) -> String {
    return "Double tap to \(action.lowercased())"
  }

  // MARK: - Badge Accessibility

  static func badgeLabel(type: String, value: String) -> String {
    return "\(type): \(value)"
  }

  // MARK: - Loading State Accessibility

  static func loadingLabel(_ context: String = "content") -> String {
    return "Loading \(context)"
  }

  // MARK: - Error State Accessibility

  static func errorLabel(_ message: String) -> String {
    return "Error: \(message)"
  }

  static func errorHint(hasRetry: Bool) -> String {
    if hasRetry {
      return "Double tap retry button to try again"
    }
    return ""
  }
}

// MARK: - View Extensions for Accessibility

extension View {
  /// Add accessibility label and hint for tasks
  func taskAccessibility(
    title: String,
    isCompleted: Bool,
    dueDate: Date?,
    isOverdue: Bool,
    hasSubtasks: Bool = false,
    subtasksCompleted: Int = 0,
    subtasksTotal: Int = 0,
    isSelectionMode: Bool = false
  ) -> some View {
    self
      .accessibilityLabel(
        Accessibility.taskLabel(
          title: title,
          isCompleted: isCompleted,
          dueDate: dueDate,
          isOverdue: isOverdue,
          hasSubtasks: hasSubtasks,
          subtasksCompleted: subtasksCompleted,
          subtasksTotal: subtasksTotal
        )
      )
      .accessibilityHint(Accessibility.taskHint(isCompleted: isCompleted, isSelectionMode: isSelectionMode))
      .accessibilityAddTraits(isCompleted ? [.isButton, .isSelected] : .isButton)
  }

  /// Add accessibility label and hint for lists
  func listAccessibility(
    title: String,
    tasksCount: Int,
    sharedCount: Int = 0
  ) -> some View {
    self
      .accessibilityLabel(Accessibility.listLabel(title: title, tasksCount: tasksCount, sharedCount: sharedCount))
      .accessibilityHint(Accessibility.listHint())
      .accessibilityAddTraits(.isButton)
  }

  /// Add semantic accessibility for buttons
  func buttonAccessibility(action: String, count: Int? = nil) -> some View {
    self
      .accessibilityLabel(Accessibility.buttonLabel(action, count: count))
      .accessibilityHint(Accessibility.buttonHint(action))
      .accessibilityAddTraits(.isButton)
  }

  /// Add accessibility for loading states
  func loadingAccessibility(context: String = "content") -> some View {
    self
      .accessibilityLabel(Accessibility.loadingLabel(context))
      .accessibilityAddTraits(.updatesFrequently)
  }

  /// Add accessibility for error states
  func errorAccessibility(message: String, hasRetry: Bool = false) -> some View {
    self
      .accessibilityLabel(Accessibility.errorLabel(message))
      .accessibilityHint(Accessibility.errorHint(hasRetry: hasRetry))
  }

  /// Mark view as a heading for VoiceOver navigation
  func accessibilityHeading() -> some View {
    self.accessibilityAddTraits(.isHeader)
  }

  /// Group accessibility elements for better navigation
  func accessibilityGroup() -> some View {
    self.accessibilityElement(children: .combine)
  }

  /// Hide decorative elements from VoiceOver
  func accessibilityHideDecorative() -> some View {
    self.accessibilityHidden(true)
  }
}

// MARK: - Dynamic Type Support

extension View {
  /// Support dynamic type scaling
  func supportsDynamicType() -> some View {
    self.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
  }

  /// Allow unlimited dynamic type scaling
  func supportsUnlimitedDynamicType() -> some View {
    self
  }
}

// MARK: - High Contrast Support

extension Color {
  /// Get high contrast variant of color for accessibility
  func highContrast() -> Color {
    return self
  }

  /// Check if current color scheme is high contrast
  static func isHighContrast(_ colorScheme: ColorScheme) -> Bool {
    // In iOS 17+, we can check UIAccessibility.isDarkerSystemColorsEnabled
    return false
  }
}

// MARK: - Reduce Motion Support

extension View {
  /// Respect reduce motion accessibility setting
  @ViewBuilder
  func respectReduceMotion<Content: View>(
    @ViewBuilder animation: () -> Content,
    @ViewBuilder staticContent: () -> Content
  ) -> some View {
    if UIAccessibility.isReduceMotionEnabled {
      staticContent()
    } else {
      animation()
    }
  }

  /// Apply animation only if reduce motion is disabled
  func animateIfAllowed<V: Equatable>(
    _ animation: Animation?,
    value: V
  ) -> some View {
    if UIAccessibility.isReduceMotionEnabled {
      return AnyView(self)
    } else {
      return AnyView(self.animation(animation, value: value))
    }
  }
}

// MARK: - Voice Control Support

extension View {
  /// Add voice control identifier
  func voiceControlIdentifier(_ identifier: String) -> some View {
    self.accessibilityIdentifier(identifier)
  }
}

// MARK: - Accessibility Testing Helpers

#if DEBUG
  struct AccessibilityTestView: View {
    var body: some View {
      VStack(spacing: DesignSystem.Spacing.lg) {
        Text("Accessibility Test View")
          .font(DesignSystem.Typography.title2)
          .accessibilityHeading()

        Button("Test Button") {}
          .buttonAccessibility(action: "Test")

        Text("Sample Task")
          .taskAccessibility(
            title: "Buy groceries",
            isCompleted: false,
            dueDate: Date(),
            isOverdue: true
          )

        Text("Loading...")
          .loadingAccessibility(context: "tasks")
      }
      .padding()
    }
  }

  struct AccessibilityHelpers_Previews: PreviewProvider {
    static var previews: some View {
      AccessibilityTestView()
    }
  }
#endif
