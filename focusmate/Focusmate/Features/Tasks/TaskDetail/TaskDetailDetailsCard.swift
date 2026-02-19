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
          value: DueDateFormatter.full(dueDate, isAnytime: self.task.isAnytime),
          valueColor: self.isOverdue ? DS.Colors.error : nil
        )
      }

      DetailRow(
        icon: "list.bullet",
        title: "List",
        value: self.listName
      )

      if let recurrence = task.recurrenceDescription {
        DetailRow(
          icon: DS.Icon.recurring,
          title: "Repeats",
          value: recurrence
        )
      }

      if self.task.isCompleted, let completedAt = task.completed_at {
        if let date = ISO8601Utils.parseDate(completedAt) {
          DetailRow(
            icon: DS.Icon.circleChecked,
            title: "Completed",
            value: DueDateFormatter.full(date, isAnytime: false),
            valueColor: DS.Colors.success
          )
        }
      }
    }
    .card()
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
      Image(systemName: self.icon)
        .foregroundStyle(.secondary)
        .frame(width: 24)

      Text(self.title)
        .font(.body)
        .foregroundStyle(.secondary)

      Spacer()

      Text(self.value)
        .font(.body)
        .foregroundStyle(self.valueColor ?? Color(.label))
    }
  }
}
