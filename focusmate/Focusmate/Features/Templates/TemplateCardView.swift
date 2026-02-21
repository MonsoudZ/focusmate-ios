import SwiftUI

struct TemplateCardView: View {
  let template: ListTemplate
  let isCreating: Bool
  let isDisabled: Bool

  private var templateColor: Color {
    ColorResolver.resolve(self.template.color)
  }

  var body: some View {
    HStack(spacing: DS.Spacing.md) {
      // Icon circle
      ZStack {
        Circle()
          .fill(self.templateColor.opacity(DS.Opacity.tintBackground))

        Image(systemName: self.template.icon)
          .scaledFont(size: 18, weight: .medium, relativeTo: .body)
          .foregroundStyle(self.templateColor)
      }
      .frame(width: 44, height: 44)

      // Info
      VStack(alignment: .leading, spacing: DS.Spacing.xs) {
        Text(self.template.name)
          .font(DS.Typography.bodyMedium)

        Text(self.template.description)
          .font(DS.Typography.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer()

      // Type badge
      Text(self.template.listType.displayName)
        .font(DS.Typography.caption2.weight(.medium))
        .foregroundStyle(self.templateColor)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xxs)
        .background(self.templateColor.opacity(DS.Opacity.tintBackground))
        .clipShape(Capsule())

      // Chevron or spinner
      if self.isCreating {
        ProgressView()
          .controlSize(.small)
      } else {
        Image(systemName: DS.Icon.chevronRight)
          .font(DS.Typography.caption)
          .foregroundStyle(.tertiary)
      }
    }
    .card()
    .opacity(self.isDisabled ? 0.5 : 1.0)
  }
}
