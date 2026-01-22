import SwiftUI

struct ListMembersView: View {
    let list: ListDTO
    let apiClient: APIClient
    
    @Environment(\.dismiss) private var dismiss
    @State private var memberships: [MembershipDTO] = []
    @State private var isLoading = true
    @State private var error: FocusmateError?
    @State private var showingInvite = false
    @State private var memberToRemove: MembershipDTO?
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if memberships.isEmpty {
                    EmptyState(
                        "No members yet",
                        message: "Invite people to collaborate on this list",
                        icon: DS.Icon.share,
                        actionTitle: "Invite Someone"
                    ) {
                        showingInvite = true
                    }
                } else {
                    List {
                        Section {
                            ForEach(memberships) { membership in
                                MemberRowView(membership: membership)
                                    .swipeActions(edge: .trailing) {
                                        Button("Remove", role: .destructive) {
                                            memberToRemove = membership
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
            .navigationTitle("Share List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingInvite = true
                    } label: {
                        Image(systemName: DS.Icon.plus)
                    }
                }
            }
            .sheet(isPresented: $showingInvite) {
                InviteMemberView(list: list, apiClient: apiClient) {
                    Task { await loadMembers() }
                }
            }
            .alert("Remove Member", isPresented: .constant(memberToRemove != nil)) {
                Button("Cancel", role: .cancel) { memberToRemove = nil }
                Button("Remove", role: .destructive) {
                    if let member = memberToRemove {
                        Task { await removeMember(member) }
                    }
                }
            } message: {
                if let member = memberToRemove {
                    Text("Remove \(member.user.name ?? member.user.email ?? "this member") from the list?")
                }
            }
            .errorBanner($error) {
                Task { await loadMembers() }
            }
            .task {
                await loadMembers()
            }
        }
    }
    
    private func loadMembers() async {
        isLoading = true
        do {
            let response: MembershipsResponse = try await apiClient.request(
                "GET",
                API.Lists.memberships(String(list.id)),
                body: nil as String?
            )
            memberships = response.memberships
        } catch let err as FocusmateError {
            error = err
        } catch {
            self.error = ErrorHandler.shared.handle(error)
        }
        isLoading = false
    }
    
    private func removeMember(_ membership: MembershipDTO) async {
        do {
            let _: EmptyResponse = try await apiClient.request(
                "DELETE",
                API.Lists.membership(String(list.id), String(membership.id)),
                body: nil as String?
            )
            memberships.removeAll { $0.id == membership.id }
            memberToRemove = nil
        } catch let err as FocusmateError {
            error = err
        } catch {
            self.error = ErrorHandler.shared.handle(error)
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
            .cornerRadius(DS.Radius.sm)
    }
}
