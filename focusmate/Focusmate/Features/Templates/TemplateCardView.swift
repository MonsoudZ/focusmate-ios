import SwiftUI

struct TemplateCardView: View {
  let template: ListTemplate
  let isCreating: Bool
  let isDisabled: Bool

  private var templateColor: Color {
    ColorResolver.resolve(template.color)
  }

  var body: some View {
    HStack(spacing: DS.Spacing.md) {
      // Icon circle
      ZStack {
        Circle()
          .fill(templateColor.opacity(DS.Opacity.tintBackground))

        Image(systemName: template.icon)
          .font(.system(size: 18, weight: .medium))
          .foregroundStyle(templateColor)
      }
      .frame(width: 44, height: 44)

      // Info
      VStack(alignment: .leading, spacing: DS.Spacing.xs) {
        Text(template.name)
          .font(DS.Typography.bodyMedium)

        Text(template.description)
          .font(DS.Typography.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer()

      // Type badge
      Text(template.listType.displayName)
        .font(DS.Typography.caption2.weight(.medium))
        .foregroundStyle(templateColor)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xxs)
        .background(templateColor.opacity(DS.Opacity.tintBackground))
        .clipShape(Capsule())

      // Chevron or spinner
      if isCreating {
        ProgressView()
          .controlSize(.small)
      } else {
        Image(systemName: DS.Icon.chevronRight)
          .font(DS.Typography.caption)
          .foregroundStyle(.tertiary)
      }
    }
    .card()
    .opacity(isDisabled ? 0.5 : 1.0)
  }
}
