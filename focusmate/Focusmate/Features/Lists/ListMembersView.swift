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
                } else if viewModel.memberships.isEmpty {
                    EmptyState(
                        "No members yet",
                        message: "Invite people to collaborate on this list",
                        icon: DS.Icon.share,
                        actionTitle: "Invite Someone"
                    ) {
                        presentInviteMember()
                    }
                } else {
                    List {
                        // Friends section
                        if !viewModel.availableFriends.isEmpty {
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
                                Text("Friends")
                            } footer: {
                                Text("Quickly add friends to this list")
                            }
                        }

                        // Invite link section
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

                        // Existing members section
                        if !viewModel.memberships.isEmpty {
                            Section {
                                ForEach(viewModel.memberships) { membership in
                                    MemberRowView(membership: membership)
                                        .swipeActions(edge: .trailing) {
                                            Button("Remove", role: .destructive) {
                                                viewModel.memberToRemove = membership
                                            }
                                        }
                                }
                            } header: {
                                Text("Members")
                            } footer: {
                                Text("Editors can add and complete tasks. Viewers can only view.")
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
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        presentInviteMember()
                    } label: {
                        Image(systemName: DS.Icon.plus)
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
                Text(membership.user.name ?? "Unknown")
                    .font(.body)
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

    var body: some View {
        Text(role.capitalized)
            .font(.caption)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(isEditor ? DS.Colors.accent.opacity(0.1) : Color.gray.opacity(0.1))
            .foregroundStyle(isEditor ? DS.Colors.accent : .gray)
            .clipShape(Capsule())
    }
}
