import SwiftUI

// Empty state views for TodayView
//
// Design concept: These are **terminal UI states** - they represent end conditions
// in the view's state machine. Each maps to a distinct application state:
// - AllClear: All tasks completed (success state)
// - NothingDue: No tasks scheduled (neutral state)
// - Empty: No data loaded (initial state)
// - Error: Load failed (failure state with retry action)

struct TodayAllClearView: View {
  var body: some View {
    VStack(spacing: DS.Spacing.md) {
      Image(systemName: DS.Icon.checkSeal)
        .font(.system(size: 64))
        .foregroundStyle(DS.Colors.success)
      Text("All Clear!")
        .font(DS.Typography.title2)
      Text("You've completed all your tasks for today!")
        .font(DS.Typography.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding(DS.Spacing.xl)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("All clear! You've completed all your tasks for today.")
  }
}

struct TodayNothingDueView: View {
  var body: some View {
    VStack(spacing: DS.Spacing.md) {
      Image(systemName: DS.Icon.calendar)
        .font(.system(size: 64))
        .foregroundStyle(DS.Colors.accent)
      Text("Nothing Due Today")
        .font(DS.Typography.title2)
      Text("Enjoy your free day or plan ahead!")
        .font(DS.Typography.body)
        .foregroundStyle(.secondary)
    }
    .padding(DS.Spacing.xl)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Nothing due today. Enjoy your free day or plan ahead.")
  }
}

struct TodayEmptyView: View {
  var body: some View {
    VStack(spacing: DS.Spacing.md) {
      Image(systemName: DS.Icon.emptyTray)
        .font(.system(size: 64))
        .foregroundStyle(DS.Colors.accent)
      Text("No tasks yet")
        .font(DS.Typography.title2)
      Text("Create a task to get started")
        .font(DS.Typography.body)
        .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("No tasks yet. Create a task to get started.")
  }
}

struct TodayErrorView: View {
  let error: FocusmateError
  let onRetry: () async -> Void

  var body: some View {
    VStack(spacing: DS.Spacing.md) {
      Image(systemName: DS.Icon.overdue)
        .font(.system(size: 64))
        .foregroundStyle(DS.Colors.error)
      Text("Something went wrong")
        .font(DS.Typography.title2)
      Button("Try Again") {
        Task { await self.onRetry() }
      }
      .buttonStyle(IntentiaPrimaryButtonStyle())
    }
    .accessibilityElement(children: .contain)
  }
}
