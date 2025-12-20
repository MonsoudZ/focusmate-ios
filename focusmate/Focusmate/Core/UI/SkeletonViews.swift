import SwiftUI

// MARK: - Skeleton Loading Components

/// A shimmering skeleton view for loading states
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

// MARK: - List Skeleton

struct ListRowSkeleton: View {
  var body: some View {
    HStack(spacing: DesignSystem.Spacing.md) {
      // Checkbox skeleton
      SkeletonView(width: 28, height: 28, cornerRadius: 14)

      VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
        // Title skeleton
        SkeletonView(width: 200, height: 16)

        // Description skeleton
        SkeletonView(width: 150, height: 12)

        HStack(spacing: DesignSystem.Spacing.xs) {
          // Date skeleton
          SkeletonView(width: 80, height: 10)

          // Badge skeleton
          SkeletonView(width: 60, height: 18, cornerRadius: DesignSystem.CornerRadius.pill)
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
        // Title skeleton
        SkeletonView(width: 150, height: 20)
        Spacer()
        // Icon skeleton
        SkeletonView(width: 24, height: 24, cornerRadius: 12)
      }

      // Description skeleton
      SkeletonView(width: 200, height: 14)
      SkeletonView(width: 180, height: 14)

      HStack(spacing: DesignSystem.Spacing.sm) {
        // Stats skeleton
        SkeletonView(width: 60, height: 12)
        SkeletonView(width: 70, height: 12)
      }
    }
    .padding(DesignSystem.Spacing.cardPadding)
    .cardStyle()
  }
}

// MARK: - Loading State Views

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

struct ItemsLoadingView: View {
  var body: some View {
    VStack(spacing: DesignSystem.Spacing.sm) {
      ForEach(0..<8, id: \.self) { _ in
        ListRowSkeleton()
      }
    }
    .padding(DesignSystem.Spacing.padding)
  }
}

// MARK: - Skeleton Modifier

extension View {
  /// Show skeleton loading overlay
  func skeleton(isLoading: Bool) -> some View {
    self.overlay(
      Group {
        if isLoading {
          SkeletonView()
        }
      }
    )
  }

  /// Replace content with skeleton when loading
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

// MARK: - Preview

#if DEBUG
  struct SkeletonViews_Previews: PreviewProvider {
    static var previews: some View {
      Group {
        // Basic skeleton
        VStack(spacing: 20) {
          SkeletonView(width: 200, height: 20)
          SkeletonView(width: 150, height: 16)
          SkeletonView(width: 100, height: 14)
        }
        .padding()
        .previewDisplayName("Basic Skeleton")

        // List row skeleton
        ListRowSkeleton()
          .previewDisplayName("List Row Skeleton")

        // List card skeleton
        ListCardSkeleton()
          .padding()
          .previewDisplayName("List Card Skeleton")

        // Lists loading view
        ListsLoadingView()
          .previewDisplayName("Lists Loading")

        // Items loading view
        ItemsLoadingView()
          .previewDisplayName("Items Loading")
      }
    }
  }
#endif
