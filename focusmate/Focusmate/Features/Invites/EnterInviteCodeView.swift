import SwiftUI

struct EnterInviteCodeView: View {
    let inviteService: InviteService
    let onAccepted: (ListDTO) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var showingAcceptView = false

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

                    Text("Enter the invite code you received")
                        .font(DS.Typography.body)
                        .foregroundStyle(.secondary)
                }

                TextField("Invite code", text: $code)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.lg)

                Spacer()

                Button("Continue") {
                    showingAcceptView = true
                }
                .buttonStyle(IntentiaPrimaryButtonStyle())
                .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xl)
            }
            .navigationTitle("Enter Invite Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAcceptView) {
                AcceptInviteView(
                    code: code.trimmingCharacters(in: .whitespacesAndNewlines),
                    inviteService: inviteService,
                    onAccepted: { list in
                        dismiss()
                        onAccepted(list)
                    }
                )
            }
        }
    }
}
