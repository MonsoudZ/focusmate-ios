import SwiftUI

struct SettingsView: View {
  @EnvironmentObject var appState: AppState
  @State private var showingEditProfile = false

  var body: some View {
    NavigationView {
      SwiftUI.List {
        Section(header: Text("Account")) {
          HStack {
            Text("Email")
            Spacer()
            if let email = appState.auth.currentUser?.email {
              Text(email)
                .foregroundColor(.secondary)
            }
          }

          HStack {
            Text("Name")
            Spacer()
            if let name = appState.auth.currentUser?.name {
              Text(name)
                .foregroundColor(.secondary)
            }
          }

          HStack {
            Text("Timezone")
            Spacer()
            if let timezone = appState.auth.currentUser?.timezone {
              Text(timezone)
                .foregroundColor(.secondary)
            }
          }

          Button("Edit Profile") {
            showingEditProfile = true
          }

          Button("Sign Out") {
            Task {
              await appState.auth.signOut()
            }
          }
          .foregroundColor(.red)
        }

        Section(header: Text("Network")) {
          HStack {
            Text("Connection Status")
            Spacer()
            if OfflineModeManager.shared.isOnline {
              Label("Online", systemImage: "wifi")
                .foregroundColor(.green)
            } else {
              Label("Offline", systemImage: "wifi.slash")
                .foregroundColor(.red)
            }
          }

          HStack {
            Text("Connection Quality")
            Spacer()
            Text(OfflineModeManager.shared.connectionQuality.rawValue)
              .foregroundColor(.secondary)
          }

          HStack {
            Text("Real-time Updates")
            Spacer()
            switch appState.webSocketManager.connectionStatus {
            case .connected:
              Label("Connected", systemImage: "bolt.circle.fill")
                .foregroundColor(.green)
            case .connecting:
              Label("Connecting", systemImage: "bolt.circle")
                .foregroundColor(.orange)
            case .disconnected:
              Label("Disconnected", systemImage: "bolt.slash.circle")
                .foregroundColor(.gray)
            case .error:
              Label("Error", systemImage: "exclamationmark.circle")
                .foregroundColor(.red)
            }
          }
        }

        #if DEBUG
        Section(header: Text("Debug & Testing")) {
          NavigationLink(destination: SwiftDataTestView()) {
            Label("SwiftData Tests", systemImage: "cylinder.split.1x2")
          }

          NavigationLink(destination: ErrorHandlingTestView()) {
            Label("Error Handling Tests", systemImage: "exclamationmark.triangle")
          }

          NavigationLink(destination: VisibilityTestView()) {
            Label("Visibility Tests", systemImage: "eye")
          }
        }
        #endif

        Section(header: Text("About")) {
          HStack {
            Text("Version")
            Spacer()
            Text("1.0.0")
              .foregroundColor(.secondary)
          }

          HStack {
            Text("Build")
            Spacer()
            Text("1")
              .foregroundColor(.secondary)
          }
        }
      }
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.large)
      .sheet(isPresented: $showingEditProfile) {
        if let user = appState.auth.currentUser {
          EditProfileView(user: user)
        }
      }
    }
  }
}

#Preview {
  SettingsView()
    .environmentObject(AppState())
}
