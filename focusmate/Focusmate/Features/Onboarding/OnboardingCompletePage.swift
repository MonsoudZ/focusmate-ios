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
                        .scaleEffect(showCheckmark ? 1.0 : 0.5)

                    Image(systemName: "checkmark")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundStyle(DS.Colors.success)
                        .scaleEffect(showCheckmark ? 1.0 : 0.0)
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCheckmark)

                VStack(spacing: DS.Spacing.sm) {
                    Text("You're All Set")
                        .font(.largeTitle.weight(.bold))

                    Text("Time to focus on what matters.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            Button(action: onFinish) {
                Text("Start Using Intentia")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(DS.Spacing.xl)
        .onAppear {
            showCheckmark = true
        }
    }
}
