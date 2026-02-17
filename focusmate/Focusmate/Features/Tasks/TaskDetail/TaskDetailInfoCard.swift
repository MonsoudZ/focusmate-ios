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
            if hasSubtasks {
                VStack(spacing: DS.Spacing.xs) {
                    MiniProgressRing(progress: subtaskProgress)
                    Text(subtaskProgressText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Creator info for shared tasks
            if isSharedTask, let creator = creator {
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
                .trim(from: 0, to: progress)
                .stroke(
                    progress >= 1.0
                        ? DS.Colors.success
                        : DS.Colors.accent,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.3), value: progress)

            if progress >= 1.0 {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DS.Colors.success)
            }
        }
        .frame(width: 32, height: 32)
    }
}
