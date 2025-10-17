import SwiftUI

@main
struct FocusmateApp: App {
    @StateObject var state = AppState()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(state).environmentObject(state.auth)
        }
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
            }
            .task { 
                print("📋 ListsView loading...")
                await auth.loadProfile() 
            }
        }
    }
}


