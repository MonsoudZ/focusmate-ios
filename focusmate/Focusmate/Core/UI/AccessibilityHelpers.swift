import SwiftUI

enum Accessibility {

    // MARK: - Shared Formatters

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    // MARK: - Task Accessibility

    static func taskLabel(
        title: String,
        isCompleted: Bool,
        dueDate: Date?,
        isOverdue: Bool
    ) -> String {
        var label = title

        if isCompleted {
            label += ", completed"
        }

        if let dueDate = dueDate {
            let dateString = dateFormatter.string(from: dueDate)

            if isOverdue && !isCompleted {
                label += ", overdue since \(dateString)"
            } else {
                label += ", due \(dateString)"
            }
        }

        return label
    }

    static func taskHint(isCompleted: Bool) -> String {
        if isCompleted {
            return "Double tap to mark as incomplete. Swipe for more options."
        } else {
            return "Double tap to mark as complete. Swipe for more options."
        }
    }

    // MARK: - List Accessibility

    static func listLabel(title: String, tasksCount: Int) -> String {
        var label = title

        if tasksCount == 0 {
            label += ", no tasks"
        } else if tasksCount == 1 {
            label += ", 1 task"
        } else {
            label += ", \(tasksCount) tasks"
        }

        return label
    }

    static func listHint() -> String {
        return "Double tap to view tasks. Swipe for more options."
    }

    // MARK: - Button Accessibility

    static func buttonLabel(_ action: String) -> String {
        return action
    }

    static func buttonHint(_ action: String) -> String {
        return "Double tap to \(action.lowercased())"
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

// MARK: - View Extensions

extension View {
    func taskAccessibility(
        title: String,
        isCompleted: Bool,
        dueDate: Date?,
        isOverdue: Bool
    ) -> some View {
        self
            .accessibilityLabel(
                Accessibility.taskLabel(
                    title: title,
                    isCompleted: isCompleted,
                    dueDate: dueDate,
                    isOverdue: isOverdue
                )
            )
            .accessibilityHint(Accessibility.taskHint(isCompleted: isCompleted))
            .accessibilityAddTraits(isCompleted ? [.isButton, .isSelected] : .isButton)
    }

    func listAccessibility(title: String, tasksCount: Int) -> some View {
        self
            .accessibilityLabel(Accessibility.listLabel(title: title, tasksCount: tasksCount))
            .accessibilityHint(Accessibility.listHint())
            .accessibilityAddTraits(.isButton)
    }

    func buttonAccessibility(action: String) -> some View {
        self
            .accessibilityLabel(Accessibility.buttonLabel(action))
            .accessibilityHint(Accessibility.buttonHint(action))
            .accessibilityAddTraits(.isButton)
    }

    func loadingAccessibility(context: String = "content") -> some View {
        self
            .accessibilityLabel(Accessibility.loadingLabel(context))
            .accessibilityAddTraits(.updatesFrequently)
    }

    func errorAccessibility(message: String, hasRetry: Bool = false) -> some View {
        self
            .accessibilityLabel(Accessibility.errorLabel(message))
            .accessibilityHint(Accessibility.errorHint(hasRetry: hasRetry))
    }

    func accessibilityHeading() -> some View {
        self.accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Reduce Motion Support

extension View {
    @ViewBuilder
    func animateIfAllowed<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        if UIAccessibility.isReduceMotionEnabled {
            self
        } else {
            self.animation(animation, value: value)
        }
    }
}
