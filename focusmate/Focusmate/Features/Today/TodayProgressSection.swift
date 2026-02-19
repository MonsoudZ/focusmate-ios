import SwiftUI

/// Progress ring and statistics for TodayView
///
/// Design concept: This is a **derived state display** - it reads from the ViewModel
/// but performs no mutations. Pure presentation component with no side effects.
struct TodayProgressSection: View {
  let progress: Double
  let isAllComplete: Bool
  let completedCount: Int
  let totalTasks: Int
  let overdueCount: Int
  let streak: StreakInfo?

  var body: some View {
    HStack(spacing: DS.Spacing.lg) {
      self.progressRing

      VStack(alignment: .leading, spacing: DS.Spacing.sm) {
        HStack(spacing: DS.Spacing.md) {
          self.miniStat(count: self.completedCount, total: self.totalTasks, label: "Done")

          if self.overdueCount > 0 {
            self.miniStat(count: self.overdueCount, label: "Overdue", color: DS.Colors.error)
          }
        }

        self.streakView
      }

      Spacer()
    }
    .heroCard()
  }

  // MARK: - Progress Ring

  private var progressRing: some View {
    ZStack {
      Circle()
        .stroke(Color(.systemGray5), lineWidth: DS.Size.progressStroke)

      Circle()
        .trim(from: 0, to: self.progress)
        .stroke(
          self.isAllComplete
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
        .animation(.easeInOut(duration: 0.5), value: self.progress)

      if self.isAllComplete {
        Image(systemName: "checkmark")
          .font(DS.Typography.title2)
          .foregroundStyle(DS.Colors.success)
      } else {
        Text("\(Int(self.progress * 100))%")
          .font(DS.Typography.title2)
      }
    }
    .frame(width: DS.Size.progressRing, height: DS.Size.progressRing)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "Progress: \(Int(self.progress * 100)) percent, \(self.completedCount) of \(self.totalTasks) tasks complete"
    )
  }

  // MARK: - Stats

  private func miniStat(count: Int, total: Int? = nil, label: String, color: Color? = nil) -> some View {
    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
      if let total {
        Text("\(count)/\(total)")
          .font(DS.Typography.title3)
          .foregroundStyle(color ?? .primary)
      } else {
        Text("\(count)")
          .font(DS.Typography.title3)
          .foregroundStyle(color ?? .primary)
      }
      Text(label)
        .font(DS.Typography.caption2)
        .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
  }

  private var streakView: some View {
    HStack(spacing: DS.Spacing.xs) {
      Text("🔥")
      if let streak, streak.current > 0 {
        Text("\(streak.current) day streak")
          .font(DS.Typography.subheadline.weight(.medium))
      } else {
        Text("Complete all tasks to start a streak!")
          .font(DS.Typography.caption)
          .foregroundStyle(.secondary)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(self.streak
      .map { $0.current > 0 ? "\($0.current) day streak" : "No streak yet" } ?? "No streak yet")
  }
}
