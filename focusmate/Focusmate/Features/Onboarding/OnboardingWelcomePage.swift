import SwiftUI

struct OnboardingWelcomePage: View {
  let onNext: () -> Void

  var body: some View {
    VStack(spacing: DS.Spacing.xxl) {
      Spacer()

      VStack(spacing: DS.Spacing.xl) {
        Image(systemName: "checkmark.seal.fill")
          .font(.system(size: DS.Size.logo))
          .foregroundStyle(DS.Colors.accent)

        VStack(spacing: DS.Spacing.md) {
          Text("Welcome to Intentia")
            .font(DS.Typography.largeTitle)
            .multilineTextAlignment(.center)

          Text("The to-do list that holds you accountable.")
            .font(DS.Typography.title3)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

          Text("Miss a deadline? Intentia blocks your distracting apps until you finish the task.")
            .font(DS.Typography.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.top, DS.Spacing.xs)
        }
      }

      Spacer()

      Button(action: self.onNext) {
        Text("Get Started")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(IntentiaPrimaryButtonStyle())
    }
    .padding(DS.Spacing.xl)
  }
}
