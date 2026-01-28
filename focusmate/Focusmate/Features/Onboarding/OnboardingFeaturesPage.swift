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
        (
            icon: "person.2.fill",
            color: DS.Colors.accent,
            title: "Collaborate",
            description: "Share lists with friends or partners to stay accountable together."
        ),
    ]

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()

            VStack(spacing: DS.Spacing.sm) {
                Text("How It Works")
                    .font(DS.Typography.largeTitle)

                Text("Four pillars to keep you on track.")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: DS.Spacing.lg) {
                ForEach(features, id: \.title) { feature in
                    HStack(spacing: DS.Spacing.lg) {
                        Image(systemName: feature.icon)
                            .font(DS.Typography.title2)
                            .foregroundStyle(feature.color)
                            .frame(width: DS.Size.iconXL, height: DS.Size.iconXL)

                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text(feature.title)
                                .font(DS.Typography.bodyMedium)

                            Text(feature.description)
                                .font(DS.Typography.subheadline)
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
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(IntentiaPrimaryButtonStyle())
        }
        .padding(DS.Spacing.xl)
    }
}
