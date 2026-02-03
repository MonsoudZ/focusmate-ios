import SwiftUI

struct ListMembersView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.router) private var router
    @State private var viewModel: ListMembersViewModel

    init(list: ListDTO, apiClient: APIClient, inviteService: InviteService, friendService: FriendService) {
        _viewModel = State(initialValue: ListMembersViewModel(list: list, apiClient: apiClient, inviteService: inviteService, friendService: friendService))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if !viewModel.isOwner && viewModel.memberships.isEmpty {
                    // Non-owners see empty state when no members loaded
                    EmptyState(
                        "No members yet",
                        message: "Only the list owner can invite members",
                        icon: DS.Icon.share
                    )
                } else {
                    List {
                        // Current members section (show first)
                        if !viewModel.memberships.isEmpty {
                            Section {
                                ForEach(viewModel.memberships) { membership in
                                    MemberRowView(membership: membership)
                                        .swipeActions(edge: .trailing) {
                                            if viewModel.isOwner && !membership.isOwner {
                                                Button("Remove", role: .destructive) {
                                                    viewModel.memberToRemove = membership
                                                }
                                            }
                                        }
                                }
                            } header: {
                                HStack {
                                    Text("Members")
                                    Spacer()
                                    Text("\(viewModel.memberships.count)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // Friends section (owners only)
                        if viewModel.isOwner && !viewModel.availableFriends.isEmpty {
                            Section {
                                ForEach(viewModel.availableFriends) { friend in
                                    FriendRowView(
                                        friend: friend,
                                        isAdding: viewModel.addingFriendId == friend.id,
                                        onAdd: {
                                            Task { await viewModel.addFriendToList(friend) }
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
                        if viewModel.isOwner {
                            Section {
                                Button {
                                    router.push(.listInvites(viewModel.list))
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
                    Button("Done") { dismiss() }
                }
                if viewModel.isOwner {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            presentInviteMember()
                        } label: {
                            Image(systemName: DS.Icon.plus)
                        }
                    }
                }
            }
            .alert("Remove Member", isPresented: .constant(viewModel.memberToRemove != nil)) {
                Button("Cancel", role: .cancel) { viewModel.memberToRemove = nil }
                Button("Remove", role: .destructive) {
                    if let member = viewModel.memberToRemove {
                        Task { await viewModel.removeMember(member) }
                    }
                }
            } message: {
                if let member = viewModel.memberToRemove {
                    Text("Remove \(member.user.name ?? member.user.email ?? "this member") from the list?")
                }
            }
            .floatingErrorBanner($viewModel.error) {
                await viewModel.loadMembers()
            }
            .task {
                await viewModel.loadMembers()
                await viewModel.loadFriends()
            }
        }
    }

    // MARK: - Sheet Presentation

    private func presentInviteMember() {
        router.sheetCallbacks.onMemberInvited = {
            Task { await viewModel.loadMembers() }
        }
        router.present(.inviteMember(viewModel.list))
    }
}

struct MemberRowView: View {
    let membership: MembershipDTO

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Avatar(membership.user.name ?? membership.user.email, size: 40)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                HStack(spacing: DS.Spacing.xs) {
                    Text(membership.user.name ?? "Unknown")
                        .font(.body)
                    if membership.isOwner {
                        Image(systemName: "crown.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
                Text(membership.user.email ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            RoleBadge(role: membership.role, isEditor: membership.isEditor)
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
            Avatar(friend.displayName, size: 40)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(friend.displayName)
                    .font(.body)
                if let email = friend.email, friend.name != nil {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                onAdd()
            } label: {
                if isAdding {
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
            .disabled(isAdding)
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}

// MARK: - Role Badge

private struct RoleBadge: View {
    let role: String
    let isEditor: Bool

    private var isOwner: Bool {
        role == "owner"
    }

    private var backgroundColor: Color {
        if isOwner {
            return Color.yellow.opacity(0.15)
        } else if isEditor {
            return DS.Colors.accent.opacity(0.1)
        } else {
            return Color.gray.opacity(0.1)
        }
    }

    private var foregroundColor: Color {
        if isOwner {
            return .orange
        } else if isEditor {
            return DS.Colors.accent
        } else {
            return .gray
        }
    }

    var body: some View {
        Text(role.capitalized)
            .font(.caption)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
    }
}
