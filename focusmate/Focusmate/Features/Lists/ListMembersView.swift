import SwiftUI

struct ListMembersView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.router) private var router
  @State private var viewModel: ListMembersViewModel

  init(list: ListDTO, apiClient: APIClient, inviteService: InviteService, friendService: FriendService) {
    _viewModel = State(initialValue: ListMembersViewModel(
      list: list,
      apiClient: apiClient,
      inviteService: inviteService,
      friendService: friendService
    ))
  }

  var body: some View {
    NavigationStack {
      Group {
        if self.viewModel.isLoading {
          ProgressView()
        } else if !self.viewModel.isOwner, self.viewModel.memberships.isEmpty {
          // Non-owners see empty state when no members loaded
          EmptyState(
            "No members yet",
            message: "Only the list owner can invite members",
            icon: DS.Icon.share
          )
        } else {
          List {
            // Current members section (show first)
            if !self.viewModel.memberships.isEmpty {
              Section {
                ForEach(self.viewModel.memberships) { membership in
                  MemberRowView(
                    membership: membership,
                    allowRoleEdit: self.viewModel.isOwner && !membership.isOwner,
                    onRoleChange: { newRole in
                      Task { await self.viewModel.updateMemberRole(membership, newRole: newRole) }
                    }
                  )
                  .swipeActions(edge: .trailing) {
                    if self.viewModel.isOwner, !membership.isOwner {
                      Button("Remove", role: .destructive) {
                        self.viewModel.memberToRemove = membership
                      }
                    }
                  }
                }
              } header: {
                HStack {
                  Text("Members")
                  Spacer()
                  Text("\(self.viewModel.memberships.count)")
                    .foregroundStyle(.secondary)
                }
              }
            }

            // Friends section (owners only)
            if self.viewModel.isOwner, !self.viewModel.availableFriends.isEmpty {
              Section {
                ForEach(self.viewModel.availableFriends) { friend in
                  FriendRowView(
                    friend: friend,
                    isAdding: self.viewModel.addingFriendId == friend.id,
                    onAdd: {
                      Task { await self.viewModel.addFriendToList(friend) }
                    }
                  )
                }
              } header: {
                Text("Add Friends")
              } footer: {
                Text("Quickly add friends to this list")
              }
            }

            // Invite link section (owners only)
            if self.viewModel.isOwner {
              Section {
                Button {
                  self.router.push(.listInvites(self.viewModel.list))
                } label: {
                  HStack {
                    Label("Create Invite Link", systemImage: "link.badge.plus")
                    Spacer()
                    Image(systemName: DS.Icon.chevronRight)
                      .font(.caption)
                      .foregroundStyle(.tertiary)
                  }
                }
                .foregroundStyle(.primary)
              } footer: {
                Text("Share a link with anyone to invite them")
              }
            }
          }
        }
      }
      .surfaceFormBackground()
      .navigationTitle("Share List")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") { self.dismiss() }
        }
        if self.viewModel.isOwner {
          ToolbarItem(placement: .primaryAction) {
            Button {
              self.presentInviteMember()
            } label: {
              Image(systemName: DS.Icon.plus)
            }
          }
        }
      }
      .alert("Remove Member", isPresented: Binding(
        get: { self.viewModel.memberToRemove != nil },
        set: { if !$0 { self.viewModel.memberToRemove = nil } }
      )) {
        Button("Cancel", role: .cancel) { self.viewModel.memberToRemove = nil }
        Button("Remove", role: .destructive) {
          if let member = viewModel.memberToRemove {
            Task { await self.viewModel.removeMember(member) }
          }
        }
      } message: {
        if let member = viewModel.memberToRemove {
          Text("Remove \(member.user.name ?? member.user.email ?? "this member") from the list?")
        }
      }
      .floatingErrorBanner(self.$viewModel.error) {
        await self.viewModel.loadMembers()
      }
      .task {
        await self.viewModel.loadMembers()
        await self.viewModel.loadFriends()
      }
    }
  }

  // MARK: - Sheet Presentation

  private func presentInviteMember() {
    self.router.sheetCallbacks.onMemberInvited = {
      Task { await self.viewModel.loadMembers() }
    }
    self.router.present(.inviteMember(self.viewModel.list))
  }
}

struct MemberRowView: View {
  let membership: MembershipDTO
  var allowRoleEdit: Bool = false
  var onRoleChange: ((String) -> Void)?

  var body: some View {
    HStack(spacing: DS.Spacing.md) {
      Avatar(self.membership.user.name ?? self.membership.user.email, size: 40)

      VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
        HStack(spacing: DS.Spacing.xs) {
          Text(self.membership.user.name ?? "Unknown")
            .font(.body)
          if self.membership.isOwner {
            Image(systemName: "crown.fill")
              .font(.caption2)
              .foregroundStyle(.yellow)
          }
        }
        Text(self.membership.user.email ?? "")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      if self.allowRoleEdit {
        Menu {
          Button {
            self.onRoleChange?("editor")
          } label: {
            Label("Editor", systemImage: "pencil")
            if self.membership.isEditor { Image(systemName: "checkmark") }
          }
          Button {
            self.onRoleChange?("viewer")
          } label: {
            Label("Viewer", systemImage: "eye")
            if self.membership.role == "viewer" { Image(systemName: "checkmark") }
          }
        } label: {
          HStack(spacing: DS.Spacing.xxs) {
            RoleBadge(role: self.membership.role, isEditor: self.membership.isEditor)
            Image(systemName: "chevron.up.chevron.down")
              .font(.system(size: 10))
              .foregroundStyle(.tertiary)
          }
        }
      } else {
        RoleBadge(role: self.membership.role, isEditor: self.membership.isEditor)
      }
    }
    .padding(.vertical, DS.Spacing.xs)
  }
}

// MARK: - Friend Row View

struct FriendRowView: View {
  let friend: FriendDTO
  let isAdding: Bool
  let onAdd: () -> Void

  var body: some View {
    HStack(spacing: DS.Spacing.md) {
      Avatar(self.friend.displayName, size: 40)

      VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
        Text(self.friend.displayName)
          .font(.body)
        if let email = friend.email, friend.name != nil {
          Text(email)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Spacer()

      Button {
        self.onAdd()
      } label: {
        if self.isAdding {
          ProgressView()
            .scaleEffect(0.8)
        } else {
          Text("Add")
            .font(.subheadline.weight(.medium))
        }
      }
      .buttonStyle(.borderedProminent)
      .buttonBorderShape(.capsule)
      .controlSize(.small)
      .disabled(self.isAdding)
    }
    .padding(.vertical, DS.Spacing.xs)
  }
}

// MARK: - Role Badge

private struct RoleBadge: View {
  let role: String
  let isEditor: Bool

  private var isOwner: Bool {
    self.role == "owner"
  }

  private var backgroundColor: Color {
    if self.isOwner {
      return Color.yellow.opacity(DS.Opacity.tintBackground)
    } else if self.isEditor {
      return DS.Colors.accent.opacity(0.1)
    } else {
      return Color.gray.opacity(0.1)
    }
  }

  private var foregroundColor: Color {
    if self.isOwner {
      return .orange
    } else if self.isEditor {
      return DS.Colors.accent
    } else {
      return .gray
    }
  }

  var body: some View {
    Text(self.role.capitalized)
      .font(.caption)
      .padding(.horizontal, DS.Spacing.sm)
      .padding(.vertical, DS.Spacing.xs)
      .background(self.backgroundColor)
      .foregroundStyle(self.foregroundColor)
      .clipShape(Capsule())
  }
}
