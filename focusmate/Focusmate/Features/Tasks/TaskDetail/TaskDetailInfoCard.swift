import SwiftUI

/// Info card showing subtask progress and creator info for shared tasks
struct TaskDetailInfoCard: View {
  let hasSubtasks: Bool
  let isSharedTask: Bool
  let subtaskProgress: Double
  let subtaskProgressText: String
  let creator: TaskCreatorDTO?

  var body: some View {
    HStack(spacing: DS.Spacing.lg) {
      // Progress ring for subtasks
      if self.hasSubtasks {
        VStack(spacing: DS.Spacing.xs) {
          MiniProgressRing(progress: self.subtaskProgress)
          Text(self.subtaskProgressText)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      // Creator info for shared tasks
      if self.isSharedTask, let creator {
        HStack(spacing: DS.Spacing.sm) {
          Avatar(creator.displayName, size: 32)
          VStack(alignment: .leading, spacing: 2) {
            Text("Created by")
              .font(.caption)
              .foregroundStyle(.secondary)
            Text(creator.displayName)
              .font(.subheadline.weight(.medium))
          }
        }
      }

      Spacer()
    }
    .card()
  }
}

// MARK: - Mini Progress Ring

struct MiniProgressRing: View {
  let progress: Double

  var body: some View {
    ZStack {
      Circle()
        .stroke(Color(.systemGray5), lineWidth: 4)

      Circle()
        .trim(from: 0, to: self.progress)
        .stroke(
          self.progress >= 1.0
            ? DS.Colors.success
            : DS.Colors.accent,
          style: StrokeStyle(lineWidth: 4, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .animateIfAllowed(.easeOut(duration: 0.3), value: self.progress)

      if self.progress >= 1.0 {
        Image(systemName: "checkmark")
          .scaledFont(size: 10, weight: .bold, relativeTo: .caption2)
          .foregroundStyle(DS.Colors.success)
      }
    }
    .frame(width: 32, height: 32)
  }
}
