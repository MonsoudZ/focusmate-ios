import SwiftUI

struct EnterInviteCodeView: View {
  let inviteService: InviteService
  let onAccepted: (ListDTO) -> Void

  @Environment(\.dismiss) private var dismiss
  @Environment(\.router) private var router
  @State private var code = ""

  var body: some View {
    NavigationStack {
      VStack(spacing: DS.Spacing.xl) {
        Spacer()

        Image(systemName: "link.badge.plus")
          .scaledFont(size: 60, relativeTo: .largeTitle)
          .foregroundStyle(DS.Colors.accent)

        VStack(spacing: DS.Spacing.sm) {
          Text("Join a Shared List")
            .scaledFont(size: 24, weight: .bold, design: .rounded, relativeTo: .title)

          Text("Enter the invite code you received")
            .font(DS.Typography.body)
            .foregroundStyle(.secondary)
        }

        TextField("Invite code", text: self.$code)
          .textFieldStyle(.roundedBorder)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .padding(.horizontal, DS.Spacing.lg)
          .padding(.top, DS.Spacing.lg)

        Spacer()

        Button("Continue") {
          let trimmedCode = self.code.trimmingCharacters(in: .whitespacesAndNewlines)
          self.dismiss()
          self.router.present(.acceptInvite(trimmedCode))
        }
        .buttonStyle(IntentiaPrimaryButtonStyle())
        .disabled(self.code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
          .buttonStyle(IntentiaToolbarCancelStyle())
        }
      }
    }
  }
}
