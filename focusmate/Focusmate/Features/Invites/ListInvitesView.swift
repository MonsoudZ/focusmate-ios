import SwiftUI

struct ListInvitesView: View {
    @Environment(\.router) private var router
    @State private var viewModel: ListInvitesViewModel

    init(list: ListDTO, inviteService: InviteService) {
        _viewModel = State(initialValue: ListInvitesViewModel(list: list, inviteService: inviteService))
    }

    var body: some View {
        List {
            // Create invite section
            Section {
                Button {
                    presentCreateInvite()
                } label: {
                    Label("Create Invite Link", systemImage: "link.badge.plus")
                }
            }

            // Existing invites
            if !viewModel.invites.isEmpty {
                Section("Active Invites") {
                    ForEach(viewModel.invites) { invite in
                        InviteRowView(invite: invite) {
                            Task { await viewModel.revokeInvite(invite) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Invite Links")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.invites.isEmpty && viewModel.error == nil {
                ContentUnavailableView(
                    "No Invites",
                    systemImage: "link",
                    description: Text("Create an invite link to share this list")
                )
            }
        }
        .task {
            await viewModel.loadInvites()
        }
        .refreshable {
            await viewModel.loadInvites()
        }
        .floatingErrorBanner($viewModel.error)
    }

    // MARK: - Sheet Presentation

    private func presentCreateInvite() {
        router.sheetCallbacks.onInviteCreated = { invite in
            router.dismissSheet()
            router.present(.shareInvite(invite))
        }
        router.present(.createInviteLink(viewModel.list))
    }
}

// MARK: - Invite Row

struct InviteRowView: View {
    let invite: InviteDTO
    let onRevoke: () -> Void

    @State private var showRevokeConfirmation = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text(invite.roleDisplayName)
                    .font(DS.Typography.bodyMedium)

                Spacer()

                statusBadge
            }

            // Invite URL (tap to copy)
            Button {
                UIPasteboard.general.string = invite.invite_url
                copied = true
                HapticManager.light()
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    copied = false
                }
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption2)
                    Text(copied ? "Copied!" : invite.invite_url)
                        .font(DS.Typography.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .foregroundStyle(copied ? DS.Colors.success : DS.Colors.accent)
            }
            .buttonStyle(.plain)

            HStack(spacing: DS.Spacing.md) {
                Label("\(invite.uses_count) accepted", systemImage: "person.fill.checkmark")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)

                if let max = invite.max_uses {
                    Label("\(max - invite.uses_count) remaining", systemImage: "person.badge.clock")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                if let expiresDate = invite.expiresDate {
                    Label(expiresDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        .font(DS.Typography.caption)
                        .foregroundStyle(invite.isExpired ? DS.Colors.error : .secondary)
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                showRevokeConfirmation = true
            } label: {
                Label("Revoke", systemImage: "trash")
            }

            if let url = URL(string: invite.invite_url) {
                ShareLink(item: url) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .tint(DS.Colors.accent)
            }
        }
        .confirmationDialog(
            "Revoke Invite",
            isPresented: $showRevokeConfirmation,
            titleVisibility: .visible
        ) {
            Button("Revoke", role: .destructive) {
                onRevoke()
            }
        } message: {
            Text("People with this link will no longer be able to join the list.")
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if invite.isExpired {
            Text("Expired")
                .font(.caption2)
                .foregroundStyle(.white)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 2)
                .background(DS.Colors.error)
                .clipShape(Capsule())
        } else if !invite.usable {
            Text("Exhausted")
                .font(.caption2)
                .foregroundStyle(.white)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 2)
                .background(Color(.systemGray))
                .clipShape(Capsule())
        } else {
            Text("Active")
                .font(.caption2)
                .foregroundStyle(.white)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 2)
                .background(DS.Colors.success)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Create Invite View

struct CreateInviteView: View {
    let viewModel: ListInvitesViewModel
    let onCreated: (InviteDTO) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var role = "viewer"
    @State private var hasExpiry = false
    @State private var expiresAt = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date().addingTimeInterval(7 * 24 * 60 * 60)
    @State private var hasMaxUses = false
    @State private var maxUses = 10
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Permissions") {
                    Picker("Role", selection: $role) {
                        Text("Can view").tag("viewer")
                        Text("Can edit").tag("editor")
                    }
                    .pickerStyle(.segmented)
                }

                Section("Expiration") {
                    Toggle("Set expiry date", isOn: $hasExpiry)

                    if hasExpiry {
                        DatePicker(
                            "Expires",
                            selection: $expiresAt,
                            in: Date()...,
                            displayedComponents: .date
                        )
                    }
                }

                Section("Usage Limit") {
                    Toggle("Limit uses", isOn: $hasMaxUses)

                    if hasMaxUses {
                        Stepper("Max uses: \(maxUses)", value: $maxUses, in: 1...100)
                    }
                }
            }
            .navigationTitle("Create Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await createInvite() }
                    } label: {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text("Create")
                        }
                    }
                    .disabled(isCreating)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func createInvite() async {
        isCreating = true

        let invite = await viewModel.createInvite(
            role: role,
            expiresAt: hasExpiry ? expiresAt : nil,
            maxUses: hasMaxUses ? maxUses : nil
        )

        isCreating = false

        if let invite {
            dismiss()
            onCreated(invite)
        }
    }
}

// MARK: - Share Invite Sheet

struct ShareInviteSheet: View {
    let invite: InviteDTO

    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.xl) {
                Spacer()

                Image(systemName: "link.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(DS.Colors.accent)

                Text("Invite Link Created")
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                // Link preview
                Text(invite.invite_url)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .padding()
                    .background(Color(.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .padding(.horizontal, DS.Spacing.lg)

                Text("Anyone with this link can \(invite.roleDisplayName.lowercased()) this list")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()

                // Actions
                VStack(spacing: DS.Spacing.md) {
                    if let url = URL(string: invite.invite_url) {
                        ShareLink(item: url) {
                            Label("Share Link", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(IntentiaPrimaryButtonStyle())
                    }

                    Button {
                        UIPasteboard.general.string = invite.invite_url
                        copied = true
                        HapticManager.light()

                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            copied = false
                        }
                    } label: {
                        Label(copied ? "Copied!" : "Copy Link", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xl)
            }
            .navigationTitle("Share Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
