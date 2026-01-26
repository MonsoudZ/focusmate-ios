import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentPage: Int = 0

    private let totalPages = 5

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $currentPage) {
                OnboardingWelcomePage(onNext: nextPage)
                    .tag(0)

                OnboardingFeaturesPage(onNext: nextPage)
                    .tag(1)

                OnboardingPermissionsPage(onNext: nextPage)
                    .tag(2)

                OnboardingCreateListPage(onNext: nextPage)
                    .tag(3)

                OnboardingCompletePage(onFinish: onComplete)
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentPage)

            // Top bar: skip button + page dots
            HStack {
                // Invisible spacer to balance the skip button
                Text("Skip")
                    .font(.body)
                    .hidden()

                Spacer()

                // Page dots
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? DS.Colors.accent : Color(.systemGray4))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }

                Spacer()

                // Skip button (hidden on last page)
                if currentPage < totalPages - 1 {
                    Button("Skip") {
                        onComplete()
                    }
                    .font(.body)
                    .foregroundStyle(.secondary)
                } else {
                    Text("Skip")
                        .font(.body)
                        .hidden()
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.sm)
        }
    }

    private func nextPage() {
        if currentPage < totalPages - 1 {
            currentPage += 1
        }
    }
}
