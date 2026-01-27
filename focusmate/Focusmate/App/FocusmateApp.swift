import SwiftUI

@MainActor
struct FocusmateApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var state: AppState
    @StateObject private var bootstrapper: AppBootstrapper

    init() {
        let auth = AuthStore()
        _state = StateObject(wrappedValue: AppState(auth: auth))
        _bootstrapper = StateObject(wrappedValue: AppBootstrapper(auth: auth))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .environmentObject(state.auth)
                .environmentObject(bootstrapper)
        }
    }
}


struct RootView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var auth: AuthStore
    @EnvironmentObject var bootstrapper: AppBootstrapper

    @State private var overdueCount: Int = 0
    @State private var selectedTab: Int = 0
    @State private var showOnboarding: Bool = !AppSettings.shared.hasCompletedOnboarding
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if auth.isValidatingSession {
                VStack {
                    ProgressView()
                    Text("Loading...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, DS.Spacing.sm)
                }
            } else if auth.jwt == nil {
                SignInView()
            } else if showOnboarding {
                OnboardingView {
                    AppSettings.shared.hasCompletedOnboarding = true
                    withAnimation {
                        showOnboarding = false
                    }
                }
                .environmentObject(state)
                .task(id: auth.jwt != nil) {
                    guard auth.jwt != nil else { return }
                    await bootstrapper.runAuthenticatedBootTasksIfNeeded()
                }
            } else {
                TabView(selection: $selectedTab) {
                    TodayView(
                        taskService: state.taskService,
                        listService: state.listService,
                        tagService: state.tagService,
                        apiClient: state.auth.api,
                        onOverdueCountChange: { count in
                            overdueCount = count
                        }
                    )
                    .tabItem {
                        Image(systemName: DS.Icon.afternoon)
                        Text("Today")
                    }
                    .tag(0)
                    .badge(overdueCount)

                    ListsView(
                        listService: state.listService,
                        taskService: state.taskService,
                        tagService: state.tagService
                    )
                        .tabItem {
                            Image(systemName: "list.bullet")
                            Text("Lists")
                        }
                        .tag(1)

                    SettingsView()
                        .tabItem {
                            Image(systemName: "gearshape")
                            Text("Settings")
                        }
                        .tag(2)
                }
                .task(id: auth.jwt != nil) {
                    guard auth.jwt != nil else { return }
                    await bootstrapper.runAuthenticatedBootTasksIfNeeded()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task { await bootstrapper.handleBecameActive() }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .openToday)) { _ in
                    selectedTab = 0
                }
                .onReceive(NotificationCenter.default.publisher(for: .openTask)) { _ in
                    selectedTab = 0
                }
                .onAppear {
                    // Flush any notification route buffered during cold start.
                    // Must happen here (not AppState.init) so .onReceive
                    // listeners are active before the post fires.
                    AppDelegate.flushPendingRouteIfAny()
                }
            }
        }
    }
}
