import SwiftUI

struct OnboardingView: View {
  let onComplete: () -> Void

  @State private var currentPage: Int = 0

  private let totalPages = 5

  var body: some View {
    ZStack(alignment: .top) {
      TabView(selection: self.$currentPage) {
        OnboardingWelcomePage(onNext: self.nextPage)
          .tag(0)

        OnboardingFeaturesPage(onNext: self.nextPage)
          .tag(1)

        OnboardingPermissionsPage(onNext: self.nextPage)
          .tag(2)

        OnboardingCreateListPage(onNext: self.nextPage)
          .tag(3)

        OnboardingCompletePage(onFinish: self.onComplete)
          .tag(4)
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .animation(DS.Anim.smooth, value: self.currentPage)
      .surfaceBackground()

      // Top bar: skip button + page dots
      HStack {
        // Invisible spacer to balance the skip button
        Text("Skip")
          .font(DS.Typography.body)
          .hidden()

        Spacer()

        // Page dots — accent color
        HStack(spacing: DS.Spacing.sm) {
          ForEach(0 ..< self.totalPages, id: \.self) { index in
            Circle()
              .fill(index == self.currentPage ? DS.Colors.accent : Color(.systemGray4))
              .frame(width: 8, height: 8)
              .animation(DS.Anim.quick, value: self.currentPage)
          }
        }

        Spacer()

        // Skip button (hidden on last page)
        if self.currentPage < self.totalPages - 1 {
          Button("Skip") {
            self.onComplete()
          }
          .font(DS.Typography.body)
          .foregroundStyle(.secondary)
        } else {
          Text("Skip")
            .font(DS.Typography.body)
            .hidden()
        }
      }
      .padding(.horizontal, DS.Spacing.xl)
      .padding(.top, DS.Spacing.sm)
    }
  }

  private func nextPage() {
    if self.currentPage < self.totalPages - 1 {
      self.currentPage += 1
    }
  }
}
