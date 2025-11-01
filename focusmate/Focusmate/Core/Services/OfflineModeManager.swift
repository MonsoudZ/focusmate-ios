import Foundation
import Network
import Combine

/// Manages offline mode and connectivity monitoring
@MainActor
final class OfflineModeManager: ObservableObject {
  static let shared = OfflineModeManager()

  @Published var isOnline = true
  @Published var connectionQuality: ConnectionQuality = .excellent
  @Published var pendingOperations: [PendingOperation] = []

  private let monitor = NWPathMonitor()
  private let monitorQueue = DispatchQueue(label: "com.focusmate.networkMonitor")
  private var cancellables = Set<AnyCancellable>()

  private init() {
    startMonitoring()
  }

  // MARK: - Network Monitoring

  func startMonitoring() {
    monitor.pathUpdateHandler = { [weak self] path in
      Task { @MainActor in
        self?.updateConnectionStatus(path: path)
      }
    }
    monitor.start(queue: monitorQueue)
    print("🌐 OfflineModeManager: Network monitoring started")
  }

  private func updateConnectionStatus(path: NWPath) {
    let wasOnline = isOnline
    isOnline = path.status == .satisfied

    // Update connection quality
    connectionQuality = determineConnectionQuality(path: path)

    // Log connection changes
    if wasOnline != isOnline {
      if isOnline {
        print("✅ OfflineModeManager: Connection restored - \(connectionQuality)")
        NotificationCenter.default.post(name: .connectionRestored, object: nil)
        Task {
          await processPendingOperations()
        }
      } else {
        print("❌ OfflineModeManager: Connection lost - going offline")
        NotificationCenter.default.post(name: .connectionLost, object: nil)
      }
    }
  }

  private func determineConnectionQuality(path: NWPath) -> ConnectionQuality {
    guard path.status == .satisfied else {
      return .offline
    }

    if path.usesInterfaceType(.wifi) {
      return .excellent
    } else if path.usesInterfaceType(.cellular) {
      return .good
    } else if path.usesInterfaceType(.wiredEthernet) {
      return .excellent
    } else {
      return .fair
    }
  }

  // MARK: - Pending Operations

  func addPendingOperation(_ operation: PendingOperation) {
    pendingOperations.append(operation)
    savePendingOperations()
    print("📝 OfflineModeManager: Added pending operation: \(operation.type)")
  }

  func removePendingOperation(_ operation: PendingOperation) {
    pendingOperations.removeAll { $0.id == operation.id }
    savePendingOperations()
  }

  private func processPendingOperations() async {
    guard isOnline, !pendingOperations.isEmpty else { return }

    print("🔄 OfflineModeManager: Processing \(pendingOperations.count) pending operations")

    let operations = pendingOperations
    for operation in operations {
      do {
        try await executeOperation(operation)
        removePendingOperation(operation)
        print("✅ OfflineModeManager: Completed pending operation: \(operation.type)")
      } catch {
        print("❌ OfflineModeManager: Failed to execute pending operation: \(error)")
        // Keep in queue for next retry
      }
    }
  }

  private func executeOperation(_ operation: PendingOperation) async throws {
    // Execute the pending operation
    // This would integrate with your services
    print("🔄 OfflineModeManager: Executing \(operation.type)")

    switch operation.type {
    case .createItem:
      // Re-execute create item request
      break
    case .updateItem:
      // Re-execute update item request
      break
    case .deleteItem:
      // Re-execute delete item request
      break
    case .completeItem:
      // Re-execute complete item request
      break
    }
  }

  private func savePendingOperations() {
    // Save to UserDefaults or persistent storage
    // For now, just in-memory
  }

  // MARK: - Helper Methods

  func requiresOnline() -> Bool {
    return !isOnline
  }

  func canPerformOperation() -> Bool {
    return isOnline
  }

  deinit {
    monitor.cancel()
  }
}

// MARK: - Supporting Types

enum ConnectionQuality: String {
  case excellent = "Excellent"
  case good = "Good"
  case fair = "Fair"
  case poor = "Poor"
  case offline = "Offline"

  var icon: String {
    switch self {
    case .excellent:
      return "wifi"
    case .good:
      return "wifi"
    case .fair:
      return "wifi"
    case .poor:
      return "wifi.slash"
    case .offline:
      return "wifi.slash"
    }
  }

  var color: String {
    switch self {
    case .excellent, .good:
      return "green"
    case .fair:
      return "yellow"
    case .poor, .offline:
      return "red"
    }
  }
}

struct PendingOperation: Identifiable, Codable {
  let id: UUID
  let type: OperationType
  let data: [String: String]
  let timestamp: Date

  init(type: OperationType, data: [String: String] = [:]) {
    self.id = UUID()
    self.type = type
    self.data = data
    self.timestamp = Date()
  }
}

enum OperationType: String, Codable {
  case createItem
  case updateItem
  case deleteItem
  case completeItem
}

// MARK: - Notification Names

extension Notification.Name {
  static let connectionRestored = Notification.Name("connectionRestored")
  static let connectionLost = Notification.Name("connectionLost")
}
