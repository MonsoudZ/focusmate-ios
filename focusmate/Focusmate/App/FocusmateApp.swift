import SwiftUI

@main
struct FocusmateApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
    @State private var selectedTab: Int = 0
    @State private var hasTrackedInitialOpen = false
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        Group {
            if auth.isValidatingSession {
                VStack {
                    ProgressView()
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
            } else if auth.jwt == nil {
                SignInView()
            } else {
                TabView(selection: $selectedTab) {
                    TodayView(onOverdueCountChange: { count in
                        overdueCount = count
                    })
                    .tabItem {
                        Image(systemName: "sun.max.fill")
                        Text("Today")
                    }
                    .tag(0)
                    .badge(overdueCount)
                    
                    ListsView()
                        .tabItem {
                            Image(systemName: DesignSystem.Icons.list)
                            Text("Lists")
                        }
                        .tag(1)
                    
                    SettingsView()
                        .tabItem {
                            Image(systemName: DesignSystem.Icons.settings)
                            Text("Settings")
                        }
                        .tag(2)
                }
                .task {
                    await NotificationService.shared.requestPermission()
                    await CalendarService.shared.requestPermission()
                    _ = EscalationService.shared
                    if !hasTrackedInitialOpen {
                        hasTrackedInitialOpen = true
                        await trackAppOpened()
                    }
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .active && oldPhase == .background {
                        Task { await trackAppOpened() }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .openToday)) { _ in
                    selectedTab = 0
                }
                .onReceive(NotificationCenter.default.publisher(for: .openTask)) { _ in
                    selectedTab = 0
                }
            }
        }
    }
    
    private func trackAppOpened() async {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        do {
            _ = try await auth.api.request(
                "POST",
                "/api/v1/analytics/app_opened",
                body: AppOpenedRequest(platform: "ios", version: version)
            ) as EmptyResponse
        } catch {
            Logger.debug("Failed to track app opened: \(error)", category: .api)
        }
    }
}

private struct AppOpenedRequest: Encodable {
    let platform: String
    let version: String?
}
