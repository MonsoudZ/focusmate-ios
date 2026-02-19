import SwiftUI

#if !targetEnvironment(simulator)
  import FamilyControls

  struct AppBlockingSettingsView: View {
    @ObservedObject private var screenTime = ScreenTimeService.shared
    @State private var showingAppPicker = false
    @State private var selection = FamilyActivitySelection()
    @State private var showingAuthError = false

    var body: some View {
      List {
        // Authorization Section
        Section {
          if self.screenTime.isAuthorized {
            HStack {
              Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(DS.Colors.success)
              Text("Screen Time Access Granted")
            }
          } else {
            Button {
              Task {
                do {
                  try await self.screenTime.requestAuthorization()
                } catch {
                  self.showingAuthError = true
                }
              }
            } label: {
              Label("Enable Screen Time Access", systemImage: "lock.shield")
            }
          }
        } header: {
          Text("Permissions")
        } footer: {
          Text("Intentia needs Screen Time access to block distracting apps when you have overdue tasks.")
        }

        // App Selection Section
        if self.screenTime.isAuthorized {
          Section {
            Button {
              self.selection.applicationTokens = self.screenTime.selectedApps
              self.selection.categoryTokens = self.screenTime.selectedCategories
              self.showingAppPicker = true
            } label: {
              HStack {
                Image(systemName: "apps.iphone")
                Text("Choose Apps to Block")
                Spacer()
                if self.screenTime.hasSelections {
                  Text("\(self.screenTime.selectedApps.count + self.screenTime.selectedCategories.count) selected")
                    .foregroundStyle(.secondary)
                }
                Image(systemName: DS.Icon.chevronRight)
                  .foregroundStyle(.secondary)
              }
            }
            .foregroundStyle(.primary)
          } header: {
            Text("Blocked Apps")
          } footer: {
            Text("Select apps and categories that will be blocked when you have overdue tasks past the grace period.")
          }

          // Current Status
          Section {
            HStack {
              Text("Blocking Active")
              Spacer()
              Text(self.screenTime.isBlocking ? "Yes" : "No")
                .foregroundStyle(self.screenTime.isBlocking ? DS.Colors.error : .secondary)
            }
          } header: {
            Text("Status")
          }

          // Test Section (for development)
          #if DEBUG
            Section {
              Button("Test: Start Blocking") {
                self.screenTime.startBlocking()
              }
              .disabled(!self.screenTime.hasSelections)

              Button("Test: Stop Blocking") {
                self.screenTime.stopBlocking()
              }
            } header: {
              Text("Debug")
            }
          #endif
        }
      }
      .surfaceFormBackground()
      .navigationTitle("App Blocking")
      .familyActivityPicker(isPresented: self.$showingAppPicker, selection: self.$selection)
      .onChange(of: self.selection) { _, newValue in
        self.screenTime.updateSelections(
          apps: newValue.applicationTokens,
          categories: newValue.categoryTokens
        )
      }
      .alert("Authorization Failed", isPresented: self.$showingAuthError) {
        Button("OK", role: .cancel) {}
        Button("Open Settings") {
          if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
          }
        }
      } message: {
        Text("Please enable Screen Time access in Settings to use app blocking.")
      }
    }
  }

#else

  // MARK: - Simulator Placeholder

  struct AppBlockingSettingsView: View {
    var body: some View {
      List {
        Section {
          HStack {
            Image(systemName: "exclamationmark.triangle")
              .foregroundStyle(.secondary)
            Text("App Blocking requires a physical device. FamilyControls is not available on Simulator.")
              .font(DS.Typography.subheadline)
              .foregroundStyle(.secondary)
          }
        } header: {
          Text("Unavailable")
        }
      }
      .surfaceFormBackground()
      .navigationTitle("App Blocking")
    }
  }

#endif
