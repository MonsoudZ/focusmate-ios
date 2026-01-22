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
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Profile Header
                Section {
                    HStack(spacing: DS.Spacing.lg) {
                        Avatar(user?.name ?? user?.email, size: DS.Size.avatarLarge)
                        
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text(user?.name ?? "No Name")
                                .font(.headline)
                            Text(user?.email ?? "")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, DS.Spacing.sm)
                }
                
                // MARK: - Account
                Section("Account") {
                    Button {
                        showingEditProfile = true
                    } label: {
                        SettingsRow("Edit Profile", icon: "person")
                    }
                    
                    if user?.hasPassword == true {
                        Button {
                            showingChangePassword = true
                        } label: {
                            SettingsRow("Change Password", icon: "lock")
                        }
                    }
                    
                    HStack {
                        Label("Timezone", systemImage: "clock")
                        Spacer()
                        Text(user?.timezone ?? "Not set")
                            .foregroundStyle(.secondary)
                    }
                }
                
                // MARK: - Notifications
                Section("Notifications") {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label("Notification Preferences", systemImage: DS.Icon.bell)
                    }
                }
                
                // MARK: - App Blocking
                Section("App Blocking") {
                    NavigationLink {
                        AppBlockingSettingsView()
                    } label: {
                        Label("Blocked Apps", systemImage: DS.Icon.shield)
                    }
                }
                
                // MARK: - About
                Section("About") {
                    HStack {
                        Label("Version", systemImage: DS.Icon.info)
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://intentia.app/privacy")!) {
                        SettingsRow("Privacy Policy", icon: "hand.raised", external: true)
                    }
                    
                    Link(destination: URL(string: "https://intentia.app/terms")!) {
                        SettingsRow("Terms of Service", icon: "doc.text", external: true)
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
                    .foregroundStyle(DS.Colors.warning)
                    
                    Button(role: .destructive) {
                        showingDeleteAccount = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Delete Account", systemImage: DS.Icon.trash)
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

// MARK: - Settings Row Helper

private struct SettingsRow: View {
    let title: String
    let icon: String
    let external: Bool
    
    init(_ title: String, icon: String, external: Bool = false) {
        self.title = title
        self.icon = icon
        self.external = external
    }
    
    var body: some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Image(systemName: external ? DS.Icon.externalLink : DS.Icon.chevronRight)
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .foregroundStyle(.primary)
    }
}
