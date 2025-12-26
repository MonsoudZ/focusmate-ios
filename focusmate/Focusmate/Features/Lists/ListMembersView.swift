import SwiftUI

struct ListMembersView: View {
    let list: ListDTO
    let apiClient: APIClient
    
    @Environment(\.dismiss) private var dismiss
    @State private var memberships: [MembershipDTO] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var showingInvite = false
    @State private var memberToRemove: MembershipDTO?
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if memberships.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2")
                            .font(.system(size: 48))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Text("No members yet")
                            .font(.headline)
                        Text("Invite people to collaborate on this list")
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Button("Invite Someone") {
                            showingInvite = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
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
                        Image(systemName: "plus")
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
            .alert("Error", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                if let error {
                    Text(error)
                }
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
        } catch {
            self.error = error.localizedDescription
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
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct MemberRowView: View {
    let membership: MembershipDTO
    
    private var initials: String {
        if let name = membership.user.name, !name.isEmpty {
            let parts = name.split(separator: " ")
            if parts.count >= 2 {
                return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
            }
            return name.prefix(2).uppercased()
        }
        return membership.user.email?.prefix(1).uppercased() ?? "?"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(DesignSystem.Colors.primary)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(initials)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(membership.user.name ?? "Unknown")
                    .font(.body)
                Text(membership.user.email ?? "")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            Text(membership.role.capitalized)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(membership.isEditor ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                .foregroundColor(membership.isEditor ? .blue : .gray)
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
}
