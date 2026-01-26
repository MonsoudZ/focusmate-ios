import SwiftUI

struct OnboardingFeaturesPage: View {
    let onNext: () -> Void

    private let features: [(icon: String, color: Color, title: String, description: String)] = [
        (
            icon: "checklist",
            color: DS.Colors.accent,
            title: "Tasks & Lists",
            description: "Organize your tasks into lists with priorities and due dates."
        ),
        (
            icon: "shield.fill",
            color: DS.Colors.error,
            title: "Accountability",
            description: "Block distracting apps until you complete your tasks."
        ),
        (
            icon: "sun.max.fill",
            color: DS.Colors.morning,
            title: "Daily Focus",
            description: "Start each day with a clear view of what needs your attention."
        ),
    ]

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()

            VStack(spacing: DS.Spacing.sm) {
                Text("How It Works")
                    .font(.largeTitle.weight(.bold))

                Text("Three pillars to keep you on track.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: DS.Spacing.lg) {
                ForEach(features, id: \.title) { feature in
                    HStack(spacing: DS.Spacing.lg) {
                        Image(systemName: feature.icon)
                            .font(.title2)
                            .foregroundStyle(feature.color)
                            .frame(width: DS.Size.iconXL, height: DS.Size.iconXL)

                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text(feature.title)
                                .font(.body.weight(.semibold))

                            Text(feature.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .card()
                }
            }

            Spacer()

            Button(action: onNext) {
                Text("Next")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(DS.Spacing.xl)
    }
}
