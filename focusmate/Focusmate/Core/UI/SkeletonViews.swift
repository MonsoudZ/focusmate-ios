import SwiftUI

struct SkeletonView: View {
    @State private var isAnimating = false

    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat

    init(
        width: CGFloat? = nil,
        height: CGFloat = 16,
        cornerRadius: CGFloat = DesignSystem.CornerRadius.sm
    ) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(DesignSystem.Colors.cardBackground)
            .frame(width: width, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.3),
                                Color.clear,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: isAnimating ? 300 : -300)
            )
            .clipped()
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

struct TaskRowSkeleton: View {
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            SkeletonView(width: 28, height: 28, cornerRadius: 14)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                SkeletonView(width: 200, height: 16)
                SkeletonView(width: 150, height: 12)

                HStack(spacing: DesignSystem.Spacing.xs) {
                    SkeletonView(width: 80, height: 10)
                    SkeletonView(width: 60, height: 18, cornerRadius: 9)
                }
            }

            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .padding(.horizontal, DesignSystem.Spacing.sm)
    }
}

struct ListCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                SkeletonView(width: 150, height: 20)
                Spacer()
                SkeletonView(width: 24, height: 24, cornerRadius: 12)
            }

            SkeletonView(width: 200, height: 14)
            SkeletonView(width: 180, height: 14)

            HStack(spacing: DesignSystem.Spacing.sm) {
                SkeletonView(width: 60, height: 12)
                SkeletonView(width: 70, height: 12)
            }
        }
        .padding(DesignSystem.Spacing.cardPadding)
        .cardStyle()
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let icon: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        title: String,
        message: String,
        icon: String = DesignSystem.Icons.empty,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(DesignSystem.Colors.textSecondary)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(title)
                    .font(DesignSystem.Typography.title3)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(DesignSystem.Typography.buttonLabel)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.primary)
                        .cornerRadius(DesignSystem.CornerRadius.button)
                }
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LoadingStateView: View {
    let message: String

    init(message: String = "Loading...") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.2)

            Text(message)
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ListsLoadingView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.md) {
                ForEach(0..<5, id: \.self) { _ in
                    ListCardSkeleton()
                }
            }
            .padding(DesignSystem.Spacing.padding)
        }
    }
}

struct TasksLoadingView: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(0..<8, id: \.self) { _ in
                TaskRowSkeleton()
            }
        }
        .padding(DesignSystem.Spacing.padding)
    }
}

extension View {
    func skeleton(isLoading: Bool) -> some View {
        self.overlay(
            Group {
                if isLoading {
                    SkeletonView()
                }
            }
        )
    }

    @ViewBuilder
    func skeletonContent<Content: View>(
        isLoading: Bool,
        @ViewBuilder skeleton: () -> Content
    ) -> some View {
        if isLoading {
            skeleton()
        } else {
            self
        }
    }
}
