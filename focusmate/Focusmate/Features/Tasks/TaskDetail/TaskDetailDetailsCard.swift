import SwiftUI

/// Details card showing due date, list, recurrence, and completion date
struct TaskDetailDetailsCard: View {
    let task: TaskDTO
    let listName: String
    let isOverdue: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if let dueDate = task.dueDate {
                DetailRow(
                    icon: DS.Icon.calendar,
                    title: "Due",
                    value: formatDueDate(dueDate, isAnytime: task.isAnytime),
                    valueColor: isOverdue ? DS.Colors.error : nil
                )
            }

            DetailRow(
                icon: "list.bullet",
                title: "List",
                value: listName
            )

            if let recurrence = task.recurrenceDescription {
                DetailRow(
                    icon: DS.Icon.recurring,
                    title: "Repeats",
                    value: recurrence
                )
            }

            if task.isCompleted, let completedAt = task.completed_at {
                if let date = ISO8601Utils.parseDate(completedAt) {
                    DetailRow(
                        icon: DS.Icon.circleChecked,
                        title: "Completed",
                        value: formatDueDate(date, isAnytime: false),
                        valueColor: DS.Colors.success
                    )
                }
            }
        }
        .card()
    }

    private func formatDueDate(_ date: Date, isAnytime: Bool) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()

        if isAnytime {
            if calendar.isDateInToday(date) { return "Today" }
            if calendar.isDateInTomorrow(date) { return "Tomorrow" }
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        }

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "'Today at' h:mm a"
        } else if calendar.isDateInTomorrow(date) {
            formatter.dateFormat = "'Tomorrow at' h:mm a"
        } else {
            formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        }

        return formatter.string(from: date)
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    var valueColor: Color?

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title)
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.body)
                .foregroundStyle(valueColor ?? Color(.label))
        }
    }
}
