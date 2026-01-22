import SwiftUI
import FamilyControls

struct AppBlockingSettingsView: View {
    @StateObject private var screenTime = ScreenTimeService.shared
    @State private var showingAppPicker = false
    @State private var selection = FamilyActivitySelection()
    @State private var showingAuthError = false
    
    var body: some View {
        List {
            // Authorization Section
            Section {
                if screenTime.isAuthorized {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(DS.Colors.success)
                        Text("Screen Time Access Granted")
                    }
                } else {
                    Button {
                        Task {
                            do {
                                try await screenTime.requestAuthorization()
                            } catch {
                                showingAuthError = true
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
            if screenTime.isAuthorized {
                Section {
                    Button {
                        // Load current selections into picker
                        selection.applicationTokens = screenTime.selectedApps
                        selection.categoryTokens = screenTime.selectedCategories
                        showingAppPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "apps.iphone")
                            Text("Choose Apps to Block")
                            Spacer()
                            if screenTime.hasSelections {
                                Text("\(screenTime.selectedApps.count + screenTime.selectedCategories.count) selected")
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
                        Text(screenTime.isBlocking ? "Yes" : "No")
                            .foregroundStyle(screenTime.isBlocking ? DS.Colors.error : .secondary)
                    }
                } header: {
                    Text("Status")
                }
                
                // Test Section (for development)
                #if DEBUG
                Section {
                    Button("Test: Start Blocking") {
                        screenTime.startBlocking()
                    }
                    .disabled(!screenTime.hasSelections)
                    
                    Button("Test: Stop Blocking") {
                        screenTime.stopBlocking()
                    }
                } header: {
                    Text("Debug")
                }
                #endif
            }
        }
        .navigationTitle("App Blocking")
        .familyActivityPicker(isPresented: $showingAppPicker, selection: $selection)
        .onChange(of: selection) { oldValue, newValue in
            screenTime.updateSelections(
                apps: newValue.applicationTokens,
                categories: newValue.categoryTokens
            )
        }
        .alert("Authorization Failed", isPresented: $showingAuthError) {
            Button("OK", role: .cancel) { }
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
