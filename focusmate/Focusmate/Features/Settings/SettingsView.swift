import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingEditProfile = false

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    HStack {
                        Text("Email")
                        Spacer()
                        if let email = appState.auth.currentUser?.email {
                            Text(email)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }

                    HStack {
                        Text("Name")
                        Spacer()
                        if let name = appState.auth.currentUser?.name {
                            Text(name)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }

                    Button("Edit Profile") {
                        showingEditProfile = true
                    }

                    Button("Sign Out", role: .destructive) {
                        Task { await appState.auth.signOut() }
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingEditProfile) {
                if let user = appState.auth.currentUser {
                    EditProfileView(user: user)
                }
            }
        }
    }
}
