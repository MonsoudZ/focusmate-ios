import SwiftUI

/// Main router class for centralized navigation state management
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    // MARK: - Tab State

    var selectedTab: Tab = .today

    // MARK: - Navigation Stack State (per tab)

    var todayPath: [Route] = []
    var listsPath: [Route] = []
    var settingsPath: [Route] = []

    // MARK: - Sheet State

    var activeSheet: Sheet?

    // MARK: - Sheet Callbacks

    /// Callbacks for sheet actions. Set these before presenting a sheet that needs callbacks.
    /// Cleared automatically when sheet is dismissed.
    var sheetCallbacks = SheetCallbacks()

    // MARK: - Deep Link Buffering

    private var pendingDeepLink: DeepLinkRoute?
    private var isReady = false

    // MARK: - Init

    private init() {}

    // MARK: - Tab Navigation

    func switchTab(to tab: Tab) {
        selectedTab = tab
    }

    // MARK: - Stack Navigation

    func push(_ route: Route, in tab: Tab? = nil) {
        let targetTab = tab ?? selectedTab
        switch targetTab {
        case .today:
            todayPath.append(route)
        case .lists:
            listsPath.append(route)
        case .settings:
            settingsPath.append(route)
        }

        if tab != nil && tab != selectedTab {
            selectedTab = targetTab
        }
    }

    func pop(in tab: Tab? = nil) {
        let targetTab = tab ?? selectedTab
        switch targetTab {
        case .today:
            if !todayPath.isEmpty { todayPath.removeLast() }
        case .lists:
            if !listsPath.isEmpty { listsPath.removeLast() }
        case .settings:
            if !settingsPath.isEmpty { settingsPath.removeLast() }
        }
    }

    func popToRoot(in tab: Tab? = nil) {
        let targetTab = tab ?? selectedTab
        switch targetTab {
        case .today:
            todayPath.removeAll()
        case .lists:
            listsPath.removeAll()
        case .settings:
            settingsPath.removeAll()
        }
    }

    // MARK: - Sheet Presentation

    func present(_ sheet: Sheet) {
        activeSheet = sheet
    }

    func dismissSheet() {
        activeSheet = nil
        sheetCallbacks = SheetCallbacks()
    }

    // MARK: - Deep Link Handling

    /// Handle a deep link route, buffering if app is not ready
    func handleDeepLink(_ route: DeepLinkRoute) {
        if isReady {
            executeDeepLink(route)
        } else {
            pendingDeepLink = route
        }
    }

    /// Mark the router as ready and flush any pending deep links
    /// Call this from RootView.onAppear when the main UI is mounted
    func markReady() {
        isReady = true
        flushPendingDeepLink()
    }

    /// Flush any buffered deep link
    private func flushPendingDeepLink() {
        guard let route = pendingDeepLink else { return }
        pendingDeepLink = nil
        executeDeepLink(route)
    }

    /// Execute a deep link route
    private func executeDeepLink(_ route: DeepLinkRoute) {
        switch route {
        case .openToday:
            selectedTab = .today

        case .openTask:
            // TODO: Implement task-specific navigation
            // For now, just switch to the today tab
            selectedTab = .today

        case .openInvite(let code):
            present(.acceptInvite(code))
        }
    }

    // MARK: - Convenience Methods

    /// Navigate to a list detail
    func navigateToList(_ list: ListDTO) {
        selectedTab = .lists
        listsPath = [.listDetail(list)]
    }

    /// Present invite code acceptance sheet
    func presentInvite(code: String) {
        present(.acceptInvite(code))
    }
}

// MARK: - Environment Key

private struct AppRouterKey: EnvironmentKey {
    static let defaultValue: AppRouter = .shared
}

extension EnvironmentValues {
    var router: AppRouter {
        get { self[AppRouterKey.self] }
        set { self[AppRouterKey.self] = newValue }
    }
}

// MARK: - Sheet Callbacks

/// Container for sheet action callbacks
/// Views set these before presenting sheets that need callbacks
@MainActor
struct SheetCallbacks {
    // Today tab callbacks
    var onTaskCreated: (() async -> Void)?
    var onTaskCompleted: ((TaskDTO) async -> Void)?
    var onTaskDeleted: ((TaskDTO) async -> Void)?
    var onTaskUpdated: (() async -> Void)?
    var onSubtaskCreated: ((TaskDTO, String) async -> Void)?
    var onSubtaskUpdated: ((SubtaskEditInfo, String) async -> Void)?

    // Lists tab callbacks
    var onListCreated: (() async -> Void)?
    var onListUpdated: (() async -> Void)?
    var onListJoined: ((ListDTO) -> Void)?

    init() {}
}
