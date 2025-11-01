import SwiftData
import SwiftUI
import UserNotifications
#if canImport(Sentry)
import Sentry
#endif

@main
struct FocusmateApp: App {
  @StateObject var state = AppState()
  @StateObject var swiftDataManager = SwiftDataManager.shared
  @StateObject var deltaSyncService: DeltaSyncService

  init() {
    // Initialize Sentry if available (added via Xcode SPM)
    configureSentryIfAvailable()
    
    let _swiftDataManager = SwiftDataManager.shared
    let _authSession = AuthSession()
    let _apiClient = NewAPIClient(auth: _authSession)
    let _deltaSyncService = DeltaSyncService(
      apiClient: _apiClient,
      swiftDataManager: _swiftDataManager,
      authSession: _authSession
    )
    self._deltaSyncService = StateObject(wrappedValue: _deltaSyncService)
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environmentObject(self.state)
        .environmentObject(self.state.auth)
        .environmentObject(self.swiftDataManager)
        .environmentObject(self.deltaSyncService)
        .modelContainer(self.swiftDataManager.modelContainer)
        .onAppear {
          self.setupPushNotifications()
        }
    }
  }

  private func setupPushNotifications() {
    // Set up notification delegate
    UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

    // Register for remote notifications
    UIApplication.shared.registerForRemoteNotifications()
  }
}

struct RootView: View {
  @EnvironmentObject var state: AppState
  @EnvironmentObject var auth: AuthStore

  var body: some View {
    if self.auth.jwt == nil {
      SignInView()
    } else {
      TabView {
        ListsView()
          .tabItem {
            Image(systemName: "list.bullet")
            Text("Lists")
          }

        BlockingTasksView()
          .tabItem {
            Image(systemName: "exclamationmark.triangle")
            Text("Blocking")
          }

        SettingsView()
          .tabItem {
            Image(systemName: "gearshape")
            Text("Settings")
          }
      }
      .task {
        print("📋 ListsView loading...")
        await self.auth.loadProfile()
      }
    }
  }
}

// MARK: - Sentry wiring (conditional)

private func configureSentryIfAvailable() {
  #if canImport(Sentry)
  guard let dsn = Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String, !dsn.isEmpty else { return }
  SentrySDK.start { o in
    o.dsn = dsn
    o.enableAutoSessionTracking = true
    o.enableNetworkTracking = true
    o.tracesSampleRate = 0.2
  }
  #if DEBUG
  SentrySDK.capture(message: "iOS Sentry wired (staging)")
  #endif
  #else
  // Sentry not linked yet; no-op
  #endif
}
