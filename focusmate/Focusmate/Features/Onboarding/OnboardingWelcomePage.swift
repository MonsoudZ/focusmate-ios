import SwiftUI

struct OnboardingWelcomePage: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()

            VStack(spacing: DS.Spacing.xl) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(DS.Colors.accent)

                VStack(spacing: DS.Spacing.sm) {
                    Text("Welcome to Intentia")
                        .font(DS.Typography.largeTitle)
                        .multilineTextAlignment(.center)

                    Text("Intentional productivity.\nFocus on what matters most.")
                        .font(DS.Typography.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            Button(action: onNext) {
                Text("Next")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(IntentiaPrimaryButtonStyle())
        }
        .padding(DS.Spacing.xl)
    }
}
