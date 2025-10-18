import SwiftUI
import UserNotifications
import SwiftData

@main
struct FocusmateApp: App {
    @StateObject var state = AppState()
    @StateObject var swiftDataManager = SwiftDataManager.shared
    @StateObject var deltaSyncService: DeltaSyncService
    
    init() {
        let _swiftDataManager = SwiftDataManager.shared
        let _deltaSyncService = DeltaSyncService(
            apiClient: APIClient(tokenProvider: { AppState().auth.jwt }),
            swiftDataManager: _swiftDataManager
        )
        self._deltaSyncService = StateObject(wrappedValue: _deltaSyncService)
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .environmentObject(state.auth)
                .environmentObject(swiftDataManager)
                .environmentObject(deltaSyncService)
                .modelContainer(swiftDataManager.modelContainer)
                .onAppear {
                    setupPushNotifications()
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
        let _ = print("🔄 RootView: jwt=\(auth.jwt != nil ? "SET" : "NIL"), currentUser=\(auth.currentUser?.email ?? "nil")")
        
        if auth.jwt == nil {
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
                
                SwiftDataTestView()
                    .tabItem {
                        Image(systemName: "wrench.and.screwdriver")
                        Text("Test")
                    }
                
                VisibilityTestView()
                    .tabItem {
                        Image(systemName: "eye")
                        Text("Visibility")
                    }
                
                ErrorHandlingTestView()
                    .tabItem {
                        Image(systemName: "exclamationmark.triangle")
                        Text("Errors")
                    }
            }
            .task { 
                print("📋 ListsView loading...")
                await auth.loadProfile() 
            }
        }
    }
}


