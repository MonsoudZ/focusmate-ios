import Foundation
import Combine

/// Centralized refresh coordination for views
/// Allows child views to trigger parent view refreshes without manual onChange handlers
@MainActor
final class RefreshCoordinator: ObservableObject {
  static let shared = RefreshCoordinator()

  private var refreshSubject = PassthroughSubject<RefreshEvent, Never>()

  var refreshPublisher: AnyPublisher<RefreshEvent, Never> {
    refreshSubject.eraseToAnyPublisher()
  }

  private init() {}

  /// Trigger a refresh for a specific entity type
  func triggerRefresh(_ event: RefreshEvent) {
    Logger.debug("RefreshCoordinator: Triggering refresh for \(event)", category: .sync)
    refreshSubject.send(event)
  }
}

/// Types of refresh events
enum RefreshEvent: Equatable {
  case lists
  case items(listId: Int)
  case list(id: Int)
  case item(id: Int)

  var description: String {
    switch self {
    case .lists:
      return "lists"
    case .items(let listId):
      return "items for list \(listId)"
    case .list(let id):
      return "list \(id)"
    case .item(let id):
      return "item \(id)"
    }
  }
}
