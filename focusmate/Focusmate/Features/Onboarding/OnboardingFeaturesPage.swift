import SwiftUI

private struct Feature: Identifiable {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var id: String { title }
}

struct OnboardingFeaturesPage: View {
    let onNext: () -> Void

    private let features: [Feature] = [
        Feature(
            icon: "checklist",
            color: DS.Colors.accent,
            title: "Tasks & Lists",
            description: "Organize your tasks with due dates. Overdue tasks trigger accountability."
        ),
        Feature(
            icon: "shield.fill",
            color: DS.Colors.error,
            title: "2-Hour Grace Period",
            description: "When a task is overdue, you get 2 hours. After that, distracting apps are blocked."
        ),
        Feature(
            icon: "sun.max.fill",
            color: DS.Colors.morning,
            title: "Daily Focus",
            description: "Start each day with a clear view of what needs your attention."
        ),
        Feature(
            icon: "person.2.fill",
            color: DS.Colors.accent,
            title: "Shared Lists",
            description: "Share lists and nudge friends to finish their tasks."
        ),
    ]

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()

            VStack(spacing: DS.Spacing.sm) {
                Text("How It Works")
                    .font(DS.Typography.largeTitle)

                Text("Accountability that actually works.")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: DS.Spacing.lg) {
                ForEach(features) { feature in
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
