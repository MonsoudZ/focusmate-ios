import SwiftUI

struct NudgeToast: View {
  let message: String

  var body: some View {
    Text(self.message)
      .font(.subheadline.weight(.medium))
      .foregroundStyle(.white)
      .padding(.horizontal, DS.Spacing.lg)
      .padding(.vertical, DS.Spacing.sm)
      .background(DS.Colors.accent)
      .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
      .shadow(DS.Shadow.sm)
      .padding(.bottom, DS.Spacing.xl)
  }
}
