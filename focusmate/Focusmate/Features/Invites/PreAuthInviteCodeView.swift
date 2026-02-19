import SwiftUI

/// A view for entering an invite code BEFORE signing in.
/// Stores the code and prompts the user to sign in to complete joining.
struct PreAuthInviteCodeView: View {
  @Binding var code: String
  let onCodeEntered: (String) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var localCode = ""

  var body: some View {
    NavigationStack {
      VStack(spacing: DS.Spacing.xl) {
        Spacer()

        Image(systemName: "link.badge.plus")
          .font(.system(size: 60))
          .foregroundStyle(DS.Colors.accent)

        VStack(spacing: DS.Spacing.sm) {
          Text("Join a Shared List")
            .font(.system(size: 24, weight: .bold, design: .rounded))

          Text("Enter your invite code, then sign in to join the list.")
            .font(DS.Typography.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
        }

        TextField("Invite code", text: self.$localCode)
          .textFieldStyle(.roundedBorder)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .padding(.horizontal, DS.Spacing.lg)
          .padding(.top, DS.Spacing.lg)

        Spacer()

        Button {
          let trimmed = self.localCode.trimmingCharacters(in: .whitespacesAndNewlines)
          self.code = trimmed
          self.onCodeEntered(trimmed)
        } label: {
          Label("Save & Sign In", systemImage: "arrow.right")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(IntentiaPrimaryButtonStyle())
        .disabled(self.localCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.xl)
      }
      .navigationTitle("Enter Invite Code")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            self.dismiss()
          }
        }
      }
    }
  }
}
