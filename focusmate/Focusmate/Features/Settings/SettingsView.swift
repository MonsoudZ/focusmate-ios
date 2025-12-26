import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingEditProfile = false
    @State private var showingChangePassword = false
    @State private var showingDeleteAccount = false
    @State private var showingSignOutConfirmation = false
    
    private var user: UserDTO? {
        appState.auth.currentUser
    }
    
    private var initials: String {
        guard let name = user?.name, !name.isEmpty else {
            return user?.email.prefix(1).uppercased() ?? "?"
        }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return name.prefix(2).uppercased()
    }
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Profile Header
                Section {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(DesignSystem.Colors.primary)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Text(initials)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user?.name ?? "No Name")
                                .font(.headline)
                            Text(user?.email ?? "")
                                .font(.subheadline)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                // MARK: - Account
                Section("Account") {
                    Button {
                        showingEditProfile = true
                    } label: {
                        HStack {
                            Label("Edit Profile", systemImage: "person")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                    
                    if user?.hasPassword == true {
                        Button {
                            showingChangePassword = true
                        } label: {
                            HStack {
                                Label("Change Password", systemImage: "lock")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        }
                    }
                    
                    HStack {
                        Label("Timezone", systemImage: "clock")
                        Spacer()
                        Text(user?.timezone ?? "Not set")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                
                // MARK: - Notifications
                Section("Notifications") {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label("Notification Preferences", systemImage: "bell")
                    }
                }
                
                // MARK: - About
                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    Link(destination: URL(string: "https://intentia.app/privacy")!) {
                        HStack {
                            Label("Privacy Policy", systemImage: "hand.raised")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.footnote)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                    
                    Link(destination: URL(string: "https://intentia.app/terms")!) {
                        HStack {
                            Label("Terms of Service", systemImage: "doc.text")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.footnote)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                }
                
                // MARK: - Danger Zone
                Section {
                    Button {
                        showingSignOutConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            Spacer()
                        }
                    }
                    .foregroundColor(.orange)
                    
                    Button(role: .destructive) {
                        showingDeleteAccount = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Delete Account", systemImage: "trash")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingEditProfile) {
                if let user {
                    EditProfileView(user: user)
                }
            }
            .sheet(isPresented: $showingChangePassword) {
                ChangePasswordView()
            }
            .sheet(isPresented: $showingDeleteAccount) {
                DeleteAccountView()
            }
            .alert("Sign Out", isPresented: $showingSignOutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    Task { await appState.auth.signOut() }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
