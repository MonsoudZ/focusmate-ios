import SwiftUI
import UIKit

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
      .fontDescriptor.withDesign(.rounded)
    {
      navAppearance.largeTitleTextAttributes = [
        .font: UIFont(descriptor: roundedDesc, size: 34),
        .foregroundColor: accentUIColor,
      ]
    }

    // Inline title: SF Rounded Semibold 17pt
    if let roundedInline = UIFont.systemFont(ofSize: 17, weight: .semibold)
      .fontDescriptor.withDesign(.rounded)
    {
      navAppearance.titleTextAttributes = [
        .font: UIFont(descriptor: roundedInline, size: 17),
      ]
    }

    UINavigationBar.appearance().standardAppearance = navAppearance
    UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    UINavigationBar.appearance().tintColor = accentUIColor
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(\.router, AppRouter.shared)
        .environmentObject(self.state)
        .environment(self.state.auth)
        .environmentObject(self.bootstrapper)
        .onOpenURL { url in
          if let route = DeepLinkRoute(url: url) {
            AppRouter.shared.handleDeepLink(route)
          }
        }
    }
  }
}

struct RootView: View {
  @EnvironmentObject var state: AppState
  @Environment(AuthStore.self) var auth
  @EnvironmentObject var bootstrapper: AppBootstrapper
  @Environment(\.router) private var router

  @State private var overdueCount: Int = 0
  @AppStorage("has_completed_onboarding") private var hasCompletedOnboarding = false
  @State private var hasCheckedLists: Bool = false
  @State private var userHasLists: Bool = true // Assume true until checked
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    Group {
      if self.auth.isValidatingSession {
        VStack {
          ProgressView()
          Text("Loading...")
            .font(DS.Typography.caption)
            .foregroundStyle(.secondary)
            .padding(.top, DS.Spacing.sm)
        }
      } else if self.auth.jwt == nil {
        SignInView()
          .sheet(item: Binding(
            get: { self.router.activeSheet },
            set: { self.router.activeSheet = $0 }
          )) { sheet in
            SheetContent(sheet: sheet, appState: self.state)
              .environmentObject(self.state)
              .environment(self.state.auth)
          }
      } else if !self.hasCompletedOnboarding || (self.hasCheckedLists && !self.userHasLists) {
        OnboardingView {
          self.userHasLists = true // After onboarding, assume they created a list
          withAnimation {
            self.hasCompletedOnboarding = true
          }
        }
        .environmentObject(self.state)
        .task(id: self.auth.jwt != nil) {
          guard self.auth.jwt != nil else { return }
          await self.bootstrapper.runAuthenticatedBootTasksIfNeeded()
        }
      } else if !self.hasCheckedLists {
        // Loading state while checking if user has lists
        VStack {
          ProgressView()
          Text("Loading...")
            .font(DS.Typography.caption)
            .foregroundStyle(.secondary)
            .padding(.top, DS.Spacing.sm)
        }
        .task {
          do {
            let lists = try await state.listService.fetchLists()
            self.userHasLists = !lists.isEmpty
          } catch {
            self.userHasLists = true // On error, don't force onboarding
          }
          self.hasCheckedLists = true
        }
      } else {
        self.mainTabView
      }
    }
    .onChange(of: self.auth.jwt) { oldJWT, newJWT in
      if oldJWT == nil, newJWT != nil {
        // Fresh login — reset list-check state so we re-evaluate
        // whether onboarding should show (hasCompletedOnboarding is
        // already reactive via @AppStorage).
        self.hasCheckedLists = false
        self.userHasLists = true
      }
    }
  }

  private var mainTabView: some View {
    TabView(selection: Binding(
      get: { self.router.selectedTab },
      set: { self.router.selectedTab = $0 }
    )) {
      TodayTab(onOverdueCountChange: { count in
        self.overdueCount = count
      })
      .tabItem {
        Image(systemName: DS.Icon.afternoon)
        Text("Today")
      }
      .tag(Tab.today)
      .badge(self.overdueCount)

      ListsTab()
        .tabItem {
          Image(systemName: "list.bullet")
          Text("Lists")
        }
        .tag(Tab.lists)

      SettingsTab()
        .tabItem {
          Image(systemName: "person.circle")
          Text("Profile")
        }
        .tag(Tab.settings)
    }
    .tint(DS.Colors.accent)
    .task(id: self.auth.jwt != nil) {
      guard self.auth.jwt != nil else { return }
      await self.bootstrapper.runAuthenticatedBootTasksIfNeeded()
    }
    .onChange(of: self.scenePhase) { _, newPhase in
      if newPhase == .active {
        Task { await self.bootstrapper.handleBecameActive() }
      }
    }
    .sheet(item: Binding(
      get: { self.router.activeSheet },
      set: { self.router.activeSheet = $0 }
    )) { sheet in
      SheetContent(sheet: sheet, appState: self.state)
        .environment(self.state.auth)
    }
    .onAppear {
      // Mark router as ready and flush any pending deep links
      self.router.markReady()
    }
  }
}
