import Combine
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

  var activeSheet: Sheet? {
    didSet {
      if self.activeSheet == nil {
        self.sheetCallbacks = SheetCallbacks()
      }
    }
  }

  // MARK: - Sheet Callbacks

  /// Callbacks for sheet actions. Set these before presenting a sheet that needs callbacks.
  /// Cleared automatically when sheet is dismissed.
  var sheetCallbacks = SheetCallbacks()

  // MARK: - Deep Link Buffering

  private var pendingDeepLinks: [DeepLinkRoute] = []
  private var isReady = false

  // MARK: - Auth Event Subscription

  private var cancellables = Set<AnyCancellable>()

  // MARK: - Init

  private init() {
    self.bindAuthEvents()
  }

  /// Listen for auth events to reset navigation on logout.
  /// This keeps the dependency one-directional (AppRouter depends on AuthEventBus,
  /// not the other way around).
  private func bindAuthEvents() {
    AuthEventBus.shared.publisher
      .receive(on: RunLoop.main)
      .sink { [weak self] event in
        if event == .signedOut {
          self?.resetAllNavigation()
        }
      }
      .store(in: &self.cancellables)
  }

  // MARK: - Tab Navigation

  func switchTab(to tab: Tab) {
    self.selectedTab = tab
  }

  // MARK: - Stack Navigation

  func push(_ route: Route, in tab: Tab? = nil) {
    let targetTab = tab ?? self.selectedTab
    switch targetTab {
    case .today:
      self.todayPath.append(route)
    case .lists:
      self.listsPath.append(route)
    case .settings:
      self.settingsPath.append(route)
    }

    if tab != nil, tab != self.selectedTab {
      self.selectedTab = targetTab
    }
  }

  func pop(in tab: Tab? = nil) {
    let targetTab = tab ?? self.selectedTab
    switch targetTab {
    case .today:
      if !self.todayPath.isEmpty { self.todayPath.removeLast() }
    case .lists:
      if !self.listsPath.isEmpty { self.listsPath.removeLast() }
    case .settings:
      if !self.settingsPath.isEmpty { self.settingsPath.removeLast() }
    }
  }

  func popToRoot(in tab: Tab? = nil) {
    let targetTab = tab ?? self.selectedTab
    switch targetTab {
    case .today:
      self.todayPath.removeAll()
    case .lists:
      self.listsPath.removeAll()
    case .settings:
      self.settingsPath.removeAll()
    }
  }

  /// Resets all navigation state. Call this on logout to prevent
  /// stale navigation data from being visible to the next user.
  func resetAllNavigation() {
    self.todayPath.removeAll()
    self.listsPath.removeAll()
    self.settingsPath.removeAll()
    self.selectedTab = .today
    self.activeSheet = nil
    self.sheetCallbacks = SheetCallbacks()
    self.pendingDeepLinks.removeAll()
    Logger.debug("AppRouter: All navigation state reset", category: .general)
  }

  // MARK: - Sheet Presentation

  func present(_ sheet: Sheet) {
    self.activeSheet = sheet
  }

  func dismissSheet() {
    self.activeSheet = nil
    self.sheetCallbacks = SheetCallbacks()
  }

  // MARK: - Deep Link Handling

  /// Handle a deep link route, buffering if app is not ready.
  /// Multiple deep links that arrive before markReady() are queued
  /// and executed in order — no link is silently dropped.
  func handleDeepLink(_ route: DeepLinkRoute) {
    if self.isReady {
      self.executeDeepLink(route)
    } else {
      self.pendingDeepLinks.append(route)
    }
  }

  /// Mark the router as ready and flush any pending deep links.
  /// Call this from RootView.onAppear when the main UI is mounted.
  func markReady() {
    self.isReady = true
    self.flushPendingDeepLinks()
  }

  /// Flush all buffered deep links in FIFO order.
  private func flushPendingDeepLinks() {
    let routes = self.pendingDeepLinks
    self.pendingDeepLinks.removeAll()
    for route in routes {
      self.executeDeepLink(route)
    }
  }

  /// Execute a deep link route
  private func executeDeepLink(_ route: DeepLinkRoute) {
    switch route {
    case .openToday:
      self.selectedTab = .today

    case let .openTask(taskId):
      self.selectedTab = .today
      self.present(.taskDeepLink(taskId))

    case let .openInvite(code):
      self.present(.acceptInvite(code))
    }
  }

  // MARK: - Convenience Methods

  /// Navigate to a list detail
  func navigateToList(_ list: ListDTO) {
    self.selectedTab = .lists
    self.listsPath = [.listDetail(list)]
  }

  /// Present invite code acceptance sheet
  func presentInvite(code: String) {
    self.present(.acceptInvite(code))
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

  // Task edit callbacks
  var onTaskSaved: (() -> Void)?
  var onOverdueReasonSubmitted: ((String) -> Void)?
  var onRescheduleSubmitted: ((Date, String) async -> Void)?
  var onTagCreated: (() async -> Void)?

  // Lists tab callbacks
  var onListCreated: (() async -> Void)?
  var onListUpdated: (() async -> Void)?
  var onListJoined: ((ListDTO) -> Void)?

  // Invite callbacks
  var onMemberInvited: (() -> Void)?
  var onInviteCreated: ((InviteDTO) -> Void)?

  /// Auth callbacks
  var onPreAuthInviteCodeEntered: ((String) -> Void)?

  init() {}
}
