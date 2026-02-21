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
        let activeCount = self.viewModel.invites.filter { $0.usable && !$0.isExpired }.count
        if activeCount >= 3 {
          HStack {
            Label("Create Invite Link", systemImage: "link.badge.plus")
              .foregroundStyle(.secondary)
            Spacer()
            Text("Max reached")
              .font(DS.Typography.caption)
              .foregroundStyle(.secondary)
          }
        } else {
          Button {
            self.presentCreateInvite()
          } label: {
            Label("Create Invite Link", systemImage: "link.badge.plus")
          }
        }
      } footer: {
        let activeCount = self.viewModel.invites.filter { $0.usable && !$0.isExpired }.count
        if activeCount > 0 {
          Text("\(activeCount) of 3 links active")
        }
      }

      // Existing invites
      if !self.viewModel.invites.isEmpty {
        Section("Active Invites") {
          ForEach(self.viewModel.invites) { invite in
            InviteRowView(invite: invite) {
              Task { await self.viewModel.revokeInvite(invite) }
            }
          }
        }
      }
    }
    .navigationTitle("Invite Links")
    .navigationBarTitleDisplayMode(.inline)
    .overlay {
      if self.viewModel.isLoading {
        ProgressView()
      } else if self.viewModel.invites.isEmpty, self.viewModel.error == nil {
        ContentUnavailableView(
          "No Invites",
          systemImage: "link",
          description: Text("Create an invite link to share this list")
        )
      }
    }
    .task {
      await self.viewModel.loadInvites()
    }
    .refreshable {
      await self.viewModel.loadInvites()
    }
    .floatingErrorBanner(self.$viewModel.error)
  }

  // MARK: - Sheet Presentation

  private func presentCreateInvite() {
    self.router.sheetCallbacks.onInviteCreated = { invite in
      self.router.dismissSheet()
      self.router.present(.shareInvite(invite))
    }
    self.router.present(.createInviteLink(self.viewModel.list))
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
        Text(self.invite.roleDisplayName)
          .font(DS.Typography.bodyMedium)

        Spacer()

        self.statusBadge
      }

      // Invite URL (tap to copy)
      Button {
        UIPasteboard.general.string = self.invite.invite_url
        self.copied = true
        HapticManager.light()
        Task {
          try? await Task.sleep(for: .seconds(2))
          self.copied = false
        }
      } label: {
        HStack(spacing: DS.Spacing.xs) {
          Image(systemName: self.copied ? "checkmark" : "doc.on.doc")
            .font(.caption2)
          Text(self.copied ? "Copied!" : self.invite.invite_url)
            .font(DS.Typography.caption)
            .lineLimit(1)
            .truncationMode(.middle)
        }
        .foregroundStyle(self.copied ? DS.Colors.success : DS.Colors.accent)
      }
      .buttonStyle(.plain)

      HStack(spacing: DS.Spacing.md) {
        Label("\(self.invite.uses_count) accepted", systemImage: "person.fill.checkmark")
          .font(DS.Typography.caption)
          .foregroundStyle(.secondary)

        if let max = invite.max_uses {
          Label("\(max - self.invite.uses_count) remaining", systemImage: "person.badge.clock")
            .font(DS.Typography.caption)
            .foregroundStyle(.secondary)
        }

        if let expiresDate = invite.expiresDate {
          Label(expiresDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
            .font(DS.Typography.caption)
            .foregroundStyle(self.invite.isExpired ? DS.Colors.error : .secondary)
        }
      }
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      Button(role: .destructive) {
        self.showRevokeConfirmation = true
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
    .alert("Revoke Invite", isPresented: self.$showRevokeConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Revoke", role: .destructive) {
        self.onRevoke()
      }
    } message: {
      Text("People with this link will no longer be able to join the list.")
    }
  }

  @ViewBuilder
  private var statusBadge: some View {
    if self.invite.isExpired {
      Text("Expired")
        .font(.caption2)
        .foregroundStyle(.white)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, 2)
        .background(DS.Colors.error)
        .clipShape(Capsule())
    } else if !self.invite.usable {
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
  @State private var hasExpiry = true
  @State private var expiresAt = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    .addingTimeInterval(7 * 24 * 60 * 60)
  @State private var hasMaxUses = false
  @State private var maxUses = 10
  @State private var isCreating = false

  var body: some View {
    NavigationStack {
      Form {
        Section("Permissions") {
          Picker("Role", selection: self.$role) {
            Text("Can view").tag("viewer")
            Text("Can edit").tag("editor")
          }
          .pickerStyle(.segmented)
        }

        Section("Expiration") {
          Toggle("Set expiry date", isOn: self.$hasExpiry)

          if self.hasExpiry {
            DatePicker(
              "Expires",
              selection: self.$expiresAt,
              in: Date()...,
              displayedComponents: .date
            )
          }
        }

        Section("Usage Limit") {
          Toggle("Limit uses", isOn: self.$hasMaxUses)

          if self.hasMaxUses {
            Stepper("Max uses: \(self.maxUses)", value: self.$maxUses, in: 1 ... 100)
          }
        }
      }
      .navigationTitle("Create Invite")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            self.dismiss()
          }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button {
            Task { await self.createInvite() }
          } label: {
            if self.isCreating {
              ProgressView()
            } else {
              Text("Create")
            }
          }
          .disabled(self.isCreating)
        }
      }
    }
    .presentationDetents([.medium])
  }

  private func createInvite() async {
    self.isCreating = true

    let invite = await viewModel.createInvite(
      role: self.role,
      expiresAt: self.hasExpiry ? self.expiresAt : nil,
      maxUses: self.hasMaxUses ? self.maxUses : nil
    )

    self.isCreating = false

    if let invite {
      self.dismiss()
      self.onCreated(invite)
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
          .scaledFont(size: 60, relativeTo: .largeTitle)
          .foregroundStyle(DS.Colors.accent)

        Text("Invite Link Created")
          .scaledFont(size: 24, weight: .bold, design: .rounded, relativeTo: .title)

        // Link preview
        Text(self.invite.invite_url)
          .font(DS.Typography.caption)
          .foregroundStyle(.secondary)
          .padding()
          .background(Color(.tertiarySystemFill))
          .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
          .padding(.horizontal, DS.Spacing.lg)

        Text("Anyone with this link can \(self.invite.roleDisplayName.lowercased()) this list")
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
            UIPasteboard.general.string = self.invite.invite_url
            self.copied = true
            HapticManager.light()

            Task {
              try? await Task.sleep(for: .seconds(2))
              self.copied = false
            }
          } label: {
            Label(self.copied ? "Copied!" : "Copy Link", systemImage: self.copied ? "checkmark" : "doc.on.doc")
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
            self.dismiss()
          }
        }
      }
    }
  }
}
