import SwiftUI

struct SettingsView: View {
  @EnvironmentObject var appState: AppState

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
    }
  }
}

#Preview {
  SettingsView()
    .environmentObject(AppState())
}
