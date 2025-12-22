import SwiftUI

@main
struct FocusmateApp: App {
    @StateObject var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .environmentObject(state.auth)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var auth: AuthStore

    var body: some View {
        Group {
            if auth.jwt == nil {
                SignInView()
            } else {
                TabView {
                    TodayView()
                        .tabItem {
                            Image(systemName: "sun.max.fill")
                            Text("Today")
                        }
                    
                    ListsView()
                        .tabItem {
                            Image(systemName: DesignSystem.Icons.list)
                            Text("Lists")
                        }

                    SettingsView()
                        .tabItem {
                            Image(systemName: DesignSystem.Icons.settings)
                            Text("Settings")
                        }
                }
            }
        }
    }
}
