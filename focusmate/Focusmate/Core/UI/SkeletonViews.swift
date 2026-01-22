import SwiftUI

// MARK: - Skeleton View

struct SkeletonView: View {
    @State private var isAnimating = false

    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat

    init(
        width: CGFloat? = nil,
        height: CGFloat = 16,
        cornerRadius: CGFloat = DS.Radius.sm
    ) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.tertiarySystemBackground))
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
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Task Row Skeleton

struct TaskRowSkeleton: View {
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            SkeletonView(width: 28, height: 28, cornerRadius: 14)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                SkeletonView(width: 200, height: 16)
                SkeletonView(width: 150, height: 12)

                HStack(spacing: DS.Spacing.xs) {
                    SkeletonView(width: 80, height: 10)
                    SkeletonView(width: 60, height: 18, cornerRadius: 9)
                }
            }

            Spacer()
        }
        .padding(.vertical, DS.Spacing.xs)
        .padding(.horizontal, DS.Spacing.sm)
    }
}

// MARK: - List Card Skeleton

struct ListCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                SkeletonView(width: 150, height: 20)
                Spacer()
                SkeletonView(width: 24, height: 24, cornerRadius: 12)
            }

            SkeletonView(width: 200, height: 14)
            SkeletonView(width: 180, height: 14)

            HStack(spacing: DS.Spacing.sm) {
                SkeletonView(width: 60, height: 12)
                SkeletonView(width: 70, height: 12)
            }
        }
        .padding(DS.Spacing.md)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(DS.Radius.md)
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let title: String
    let message: String
    let icon: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        title: String,
        message: String,
        icon: String = DS.Icon.emptyTray,
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
        VStack(spacing: DS.Spacing.xl) {
            Image(systemName: icon)
                .font(.system(size: DS.Size.iconJumbo))
                .foregroundStyle(.secondary)

            VStack(spacing: DS.Spacing.sm) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Loading State View

struct LoadingStateView: View {
    let message: String

    init(message: String = "Loading...") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.2)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Lists Loading View

struct ListsLoadingView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.md) {
                ForEach(0..<5, id: \.self) { _ in
                    ListCardSkeleton()
                }
            }
            .padding(DS.Spacing.lg)
        }
    }
}

// MARK: - Tasks Loading View

struct TasksLoadingView: View {
    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(0..<8, id: \.self) { _ in
                TaskRowSkeleton()
            }
        }
        .padding(DS.Spacing.lg)
    }
}

// MARK: - View Extensions

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
