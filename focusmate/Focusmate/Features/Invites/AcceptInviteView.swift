import SwiftUI

struct AcceptInviteView: View {
    let code: String
    let inviteService: InviteService
    let onAccepted: (ListDTO) -> Void

    @EnvironmentObject var auth: AuthStore
    @Environment(\.dismiss) private var dismiss

    @State private var preview: InvitePreviewDTO?
    @State private var isLoading = true
    @State private var isAccepting = false
    @State private var error: FocusmateError?
    @State private var acceptedList: ListDTO?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if let acceptedList {
                    successView(list: acceptedList)
                } else if let error {
                    errorView(error)
                } else if let preview {
                    invitePreview(preview)
                }
            }
            .navigationTitle("List Invitation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadPreview()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: DS.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading invitation...")
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Invite Preview

    private func invitePreview(_ preview: InvitePreviewDTO) -> some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            // Icon
            Image(systemName: "envelope.open.fill")
                .font(.system(size: 60))
                .foregroundStyle(DS.Colors.accent)

            // Invitation text
            VStack(spacing: DS.Spacing.sm) {
                if let inviterName = preview.inviterName {
                    Text("\(inviterName) invited you to")
                        .font(DS.Typography.body)
                        .foregroundStyle(.secondary)
                } else {
                    Text("You've been invited to")
                        .font(DS.Typography.body)
                        .foregroundStyle(.secondary)
                }

                Text(preview.listName)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("You'll be able to \(preview.roleDisplayName) tasks in this list")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DS.Spacing.lg)

            Spacer()

            // Actions
            VStack(spacing: DS.Spacing.md) {
                if auth.jwt != nil {
                    Button {
                        Task { await acceptInvite() }
                    } label: {
                        if isAccepting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Join List")
                        }
                    }
                    .buttonStyle(IntentiaPrimaryButtonStyle())
                    .disabled(isAccepting || !preview.usable)
                } else {
                    Text("Sign in to accept this invitation")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)

                    Button("Sign In") {
                        dismiss()
                    }
                    .buttonStyle(IntentiaPrimaryButtonStyle())
                }

                if !preview.usable {
                    Text("This invitation is no longer valid")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.error)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xl)
        }
    }

    // MARK: - Success View

    private func successView(list: ListDTO) -> some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(DS.Colors.success)

            VStack(spacing: DS.Spacing.sm) {
                Text("You joined")
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)

                Text(list.name)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
            }

            Spacer()

            Button("View List") {
                onAccepted(list)
                dismiss()
            }
            .buttonStyle(IntentiaPrimaryButtonStyle())
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xl)
        }
    }

    // MARK: - Error View

    private func errorView(_ error: FocusmateError) -> some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(DS.Colors.error)

            VStack(spacing: DS.Spacing.sm) {
                Text("Unable to load invitation")
                    .font(DS.Typography.bodyMedium)

                Text(error.message)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DS.Spacing.lg)

            Spacer()

            Button("Try Again") {
                Task { await loadPreview() }
            }
            .buttonStyle(IntentiaPrimaryButtonStyle())
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xl)
        }
    }

    // MARK: - Actions

    private func loadPreview() async {
        isLoading = true
        error = nil

        do {
            preview = try await inviteService.previewInvite(code: code)
        } catch let err as FocusmateError {
            error = err
        } catch {
            self.error = .custom("INVITE_ERROR", "Failed to load invitation")
        }

        isLoading = false
    }

    private func acceptInvite() async {
        isAccepting = true
        error = nil

        do {
            let response = try await inviteService.acceptInvite(code: code)
            acceptedList = response.list
            HapticManager.success()
        } catch let err as FocusmateError {
            error = err
            HapticManager.error()
        } catch {
            self.error = .custom("INVITE_ERROR", "Failed to join list")
            HapticManager.error()
        }

        isAccepting = false
    }
}
