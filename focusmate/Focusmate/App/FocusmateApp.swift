import SwiftUI
import UIKit

extension String: @retroactive Identifiable {
    public var id: String { self }
}

@MainActor
struct FocusmateApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var state: AppState
    @StateObject private var bootstrapper: AppBootstrapper

    init() {
        let auth = AuthStore()
        _state = StateObject(wrappedValue: AppState(auth: auth))
        _bootstrapper = StateObject(wrappedValue: AppBootstrapper(auth: auth))

        Self.configureAppearance()
    }

    private static func configureAppearance() {
        let accentUIColor = UIColor(Color("AccentColor"))

        // Tab bar
        UITabBar.appearance().tintColor = accentUIColor

        // Navigation bar — SF Rounded large titles + accent tint
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()

        // Large title: SF Rounded Bold 34pt
        if let roundedDesc = UIFont.systemFont(ofSize: 34, weight: .bold)
            .fontDescriptor.withDesign(.rounded) {
            navAppearance.largeTitleTextAttributes = [
                .font: UIFont(descriptor: roundedDesc, size: 34),
                .foregroundColor: accentUIColor
            ]
        }

        // Inline title: SF Rounded Semibold 17pt
        if let roundedInline = UIFont.systemFont(ofSize: 17, weight: .semibold)
            .fontDescriptor.withDesign(.rounded) {
            navAppearance.titleTextAttributes = [
                .font: UIFont(descriptor: roundedInline, size: 17)
            ]
        }

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().tintColor = accentUIColor
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .environmentObject(state.auth)
                .environmentObject(bootstrapper)
                .onOpenURL { url in
                    _ = AppDelegate.handleIncomingURL(url)
                }
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
    @State private var inviteCode: String?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if auth.isValidatingSession {
                VStack {
                    ProgressView()
                    Text("Loading...")
                        .font(DS.Typography.caption)
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
                        tagService: state.tagService,
                        inviteService: state.inviteService,
                        friendService: state.friendService
                    )
                        .tabItem {
                            Image(systemName: "list.bullet")
                            Text("Lists")
                        }
                        .tag(1)

                    SettingsView()
                        .tabItem {
                            Image(systemName: "person.circle")
                            Text("Profile")
                        }
                        .tag(2)
                }
                .tint(DS.Colors.accent)
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
                .onReceive(NotificationCenter.default.publisher(for: .openInvite)) { notification in
                    if let code = notification.userInfo?["code"] as? String {
                        inviteCode = code
                    }
                }
                .sheet(item: $inviteCode) { code in
                    AcceptInviteView(
                        code: code,
                        inviteService: state.inviteService,
                        onAccepted: { _ in
                            inviteCode = nil
                            selectedTab = 1 // Go to Lists tab
                        }
                    )
                    .environmentObject(state.auth)
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
