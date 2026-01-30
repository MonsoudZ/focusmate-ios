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
        cornerRadius: CGFloat = DS.Radius.xs
    ) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(.tertiarySystemBackground))
            .frame(width: width, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
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
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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
                    SkeletonView(width: 60, height: 18, cornerRadius: DS.Radius.xs)
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
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
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
                .font(DS.Typography.subheadline)
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
