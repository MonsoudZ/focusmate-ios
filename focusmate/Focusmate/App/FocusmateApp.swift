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
    @State private var overdueCount: Int = 0
    
    var body: some View {
        Group {
            if auth.jwt == nil {
                SignInView()
            } else {
                TabView {
                    TodayView(onOverdueCountChange: { count in
                        overdueCount = count
                    })
                    .tabItem {
                        Image(systemName: "sun.max.fill")
                        Text("Today")
                    }
                    .badge(overdueCount)
                    
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
                .task {
                    await NotificationService.shared.requestPermission()
                    await CalendarService.shared.requestPermission()
                }
            }
        }
    }
}
