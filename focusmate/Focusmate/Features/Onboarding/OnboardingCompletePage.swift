import SwiftUI

struct OnboardingCompletePage: View {
  let onFinish: () -> Void

  @State private var showCheckmark = false

  var body: some View {
    VStack(spacing: DS.Spacing.xxl) {
      Spacer()

      VStack(spacing: DS.Spacing.xl) {
        ZStack {
          Circle()
            .fill(DS.Colors.success.opacity(0.15))
            .frame(width: 120, height: 120)
            .scaleEffect(self.showCheckmark ? 1.0 : 0.5)

          Image(systemName: "checkmark")
            .font(.system(size: 50, weight: .bold))
            .foregroundStyle(DS.Colors.success)
            .scaleEffect(self.showCheckmark ? 1.0 : 0.0)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: self.showCheckmark)

        VStack(spacing: DS.Spacing.sm) {
          Text("You're All Set")
            .font(DS.Typography.largeTitle)

          Text("Add a task with a due date and see accountability in action.")
            .font(DS.Typography.title3)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
      }

      Spacer()

      Button(action: self.onFinish) {
        Text("Start Using Intentia")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(IntentiaPrimaryButtonStyle())
    }
    .padding(DS.Spacing.xl)
    .onAppear {
      self.showCheckmark = true
    }
  }
}
