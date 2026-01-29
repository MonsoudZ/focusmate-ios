import SwiftUI

struct ListMembersView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ListMembersViewModel

    init(list: ListDTO, apiClient: APIClient, inviteService: InviteService) {
        _viewModel = State(initialValue: ListMembersViewModel(list: list, apiClient: apiClient, inviteService: inviteService))
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
                        viewModel.showingInvite = true
                    }
                } else {
                    List {
                        // Invite link section
                        Section {
                            NavigationLink {
                                ListInvitesView(list: viewModel.list, inviteService: viewModel.inviteService)
                            } label: {
                                Label("Invite Links", systemImage: "link")
                            }
                        } footer: {
                            Text("Create shareable links to invite people to this list")
                        }

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
            .surfaceFormBackground()
            .navigationTitle("Share List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.showingInvite = true
                    } label: {
                        Image(systemName: DS.Icon.plus)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingInvite) {
                InviteMemberView(list: viewModel.list, apiClient: viewModel.apiClient) {
                    Task { await viewModel.loadMembers() }
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
            .errorBanner($viewModel.error) {
                Task { await viewModel.loadMembers() }
            }
            .task {
                await viewModel.loadMembers()
            }
        }
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
