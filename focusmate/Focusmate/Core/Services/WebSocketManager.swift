import Combine
import Foundation

extension Notification.Name {
  static let webSocketConnectionFailed = Notification.Name("webSocketConnectionFailed")
  static let performDataSync = Notification.Name("performDataSync")
}

class WebSocketManager: ObservableObject {
  private var webSocketTask: URLSessionWebSocketTask?
  private var urlSession: URLSession?
  private var reconnectTimer: Timer?
  private var isConnected = false

  @Published var connectionStatus: ConnectionStatus = .disconnected
  @Published var lastError: String?

  enum ConnectionStatus: Equatable {
    case connected
    case connecting
    case disconnected
    case error(String)
  }

  // MARK: - Connection Management

  private var token: String?

  func connect(with token: String) {
    guard !self.isConnected else { return }

    self.token = token
    self.connectionStatus = .connecting

    // Use centralized WebSocket URL from API configuration
    let baseURL = API.webSocketURL
    #if DEBUG
    print("🔌 WebSocketManager: Using WebSocket URL: \(baseURL.absoluteString)")
    #endif

    var urlComponents = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
    urlComponents?.queryItems = [URLQueryItem(name: "token", value: token)]

    guard let webSocketURL = urlComponents?.url else {
      self.connectionStatus = .error("Failed to construct WebSocket URL")
      return
    }

    #if DEBUG
    print("🔌 WebSocketManager: Connecting to \(webSocketURL)")
    #endif

    // Create URLSession with enhanced configuration for ActionCable
    let config = URLSessionConfiguration.default
    config.httpAdditionalHeaders = [
      "ngrok-skip-browser-warning": "true",
      "User-Agent": "Focusmate-iOS/1.0",
      "Accept": "application/json",
    ]

    // Set connection timeout
    config.timeoutIntervalForRequest = 10.0
    config.timeoutIntervalForResource = 30.0

    self.urlSession = URLSession(configuration: config)
    self.webSocketTask = self.urlSession?.webSocketTask(with: webSocketURL)

    // Add connection timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
      if self?.connectionStatus == .connecting {
        #if DEBUG
        print("🔌 WebSocketManager: Connection timeout")
        #endif
        self?.connectionStatus = .error("Connection timeout")
        self?.disconnect()
      }
    }

    self.startListening()
    // Don't send welcome message immediately - wait for connection
  }

  func disconnect() {
    #if DEBUG
    print("🔌 WebSocketManager: Disconnecting")
    #endif
    self.webSocketTask?.cancel(with: .goingAway, reason: nil)
    self.webSocketTask = nil
    self.urlSession = nil
    self.isConnected = false
    self.connectionStatus = .disconnected
    self.reconnectTimer?.invalidate()
    self.reconnectTimer = nil
  }

  // MARK: - Message Handling

  private func startListening() {
    self.webSocketTask?.resume()
    self.receiveMessage()
  }

  private func receiveMessage() {
    self.webSocketTask?.receive { [weak self] result in
      switch result {
      case let .success(message):
        #if DEBUG
        print("🔌 WebSocketManager: Message received successfully")
        #endif
        self?.handleMessage(message)
        self?.receiveMessage() // Continue listening
      case let .failure(error):
        #if DEBUG
        print("🔌 WebSocketManager: Receive error: \(error)")
        #endif
        self?.handleConnectionError(error)
      }
    }
  }

  private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
    switch message {
    case let .string(text):
      #if DEBUG
      print("🔌 WebSocketManager: Received: \(text)")
      #endif
      self.handleTextMessage(text)
    case let .data(data):
      #if DEBUG
      print("🔌 WebSocketManager: Received data: \(data.count) bytes")
      #endif
      if let text = String(data: data, encoding: .utf8) {
        self.handleTextMessage(text)
      }
    @unknown default:
      #if DEBUG
      print("🔌 WebSocketManager: Unknown message type")
      #endif
    }
  }

  private func handleTextMessage(_ text: String) {
    guard let data = text.data(using: .utf8) else { return }

    do {
      // Parse ActionCable message format
      if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
        self.handleActionCableMessage(json)
      }
    } catch {
      #if DEBUG
      print("🔌 WebSocketManager: JSON parsing error: \(error)")
      #endif
    }
  }

  private func handleActionCableMessage(_ message: [String: Any]) {
    // Handle different ActionCable message types
    if let type = message["type"] as? String {
      switch type {
      case "welcome":
        self.handleWelcome()
      case "ping":
        self.handlePing()
      case "confirm_subscription":
        self.handleSubscriptionConfirmation()
      case "reject_subscription":
        self.handleSubscriptionRejection()
      default:
        #if DEBUG
        print("🔌 WebSocketManager: Unknown message type: \(type)")
        #endif
      }
    }

    // Handle data messages (task updates)
    if let message = message["message"] as? [String: Any] {
      self.handleTaskUpdate(message)
    }
  }

  private func handleWelcome() {
    #if DEBUG
    print("🔌 WebSocketManager: Welcome message received")
    #endif
    self.isConnected = true
    self.connectionStatus = .connected
    self.subscribeToTaskUpdates()
  }

  private func handlePing() {
    // Respond to ping with pong
    self.sendPong()
  }

  private func handleSubscriptionConfirmation() {
    #if DEBUG
    print("🔌 WebSocketManager: Subscription confirmed")
    #endif
  }

  private func handleSubscriptionRejection() {
    #if DEBUG
    print("🔌 WebSocketManager: Subscription rejected")
    #endif
    self.connectionStatus = .error("Subscription rejected")
  }

  private func handleTaskUpdate(_ message: [String: Any]) {
    #if DEBUG
    print("🔌 WebSocketManager: Task update received: \(message)")
    #endif

    // Parse task update and notify observers
    if let taskData = message["task"] as? [String: Any] {
      NotificationCenter.default.post(
        name: .taskUpdated,
        object: nil,
        userInfo: ["task": taskData]
      )
    }
  }

  // MARK: - Message Sending

  private func sendWelcomeMessage() {
    let welcomeMessage = [
      "command": "subscribe",
      "identifier": "{\"channel\":\"TaskChannel\"}",
    ]
    self.sendMessage(welcomeMessage)
  }

  private func subscribeToTaskUpdates() {
    let subscribeMessage = [
      "command": "subscribe",
      "identifier": "{\"channel\":\"TaskChannel\"}",
    ]
    self.sendMessage(subscribeMessage)
  }

  private func sendPong() {
    let pongMessage = [
      "command": "message",
      "identifier": "{\"channel\":\"TaskChannel\"}",
      "data": "{\"action\":\"pong\"}",
    ]
    self.sendMessage(pongMessage)
  }

  private func sendMessage(_ message: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: message),
          let jsonString = String(data: data, encoding: .utf8)
    else {
      #if DEBUG
      print("🔌 WebSocketManager: Failed to serialize message")
      #endif
      return
    }

    self.webSocketTask?.send(.string(jsonString)) { error in
      if let error {
        #if DEBUG
        print("🔌 WebSocketManager: Send error: \(error)")
        #endif
      }
    }
  }

  // MARK: - Error Handling

  private func handleConnectionError(_ error: Error) {
    #if DEBUG
    print("🔌 WebSocketManager: Connection error: \(error)")
    #endif
    self.isConnected = false

    // Enhanced error handling for specific WebSocket issues
    if let urlError = error as? URLError {
      switch urlError.code {
      case .badServerResponse:
        #if DEBUG
        print("🔌 WebSocketManager: Bad server response - ActionCable WebSocket handshake failed")
        #endif
        #if DEBUG
        print("🔌 WebSocketManager: This usually means the server doesn't support WebSocket or has configuration issues")
        #endif
        self.connectionStatus = .error("WebSocket handshake failed - using HTTP polling")
        self.startHttpPolling()
        return
      case .timedOut:
        #if DEBUG
        print("🔌 WebSocketManager: Connection timeout")
        #endif
        self.connectionStatus = .error("Connection timeout")
      case .notConnectedToInternet:
        #if DEBUG
        print("🔌 WebSocketManager: No internet connection")
        #endif
        self.connectionStatus = .error("No internet connection")
      case .cannotConnectToHost:
        #if DEBUG
        print("🔌 WebSocketManager: Cannot connect to host")
        #endif
        self.connectionStatus = .error("Cannot connect to server")
      default:
        #if DEBUG
        print("🔌 WebSocketManager: URL error: \(urlError.localizedDescription)")
        #endif
        self.connectionStatus = .error(urlError.localizedDescription)
      }
    } else {
      self.connectionStatus = .error(error.localizedDescription)
    }

    self.lastError = error.localizedDescription

    // Attempt to reconnect after a delay
    self.scheduleReconnect()
  }

  private func scheduleReconnect() {
    self.reconnectTimer?.invalidate()
    self.reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
      #if DEBUG
      print("🔌 WebSocketManager: Attempting to reconnect...")
      #endif
      // Note: Would need the token to reconnect
    }
  }

  private func startHttpPolling() {
    #if DEBUG
    print("🔌 WebSocketManager: Starting HTTP polling fallback")
    #endif
    #if DEBUG
    print("🔌 WebSocketManager: WebSocket connection failed, using HTTP polling for real-time updates")
    #endif
    self.connectionStatus = .connected // Mark as connected for polling mode
    self.isConnected = true

    // Start polling for updates every 30 seconds
    self.reconnectTimer?.invalidate()
    self.reconnectTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
      self.pollForUpdates()
    }

    // Notify the app that we're using HTTP polling
    NotificationCenter.default.post(name: .webSocketConnectionFailed, object: nil)
  }

  private func pollForUpdates() {
    #if DEBUG
    print("🔌 WebSocketManager: Polling for updates...")
    #endif

    // Perform HTTP polling to check for updates
    // This triggers a sync to get the latest data
    Task {
      await self.performDataSync()
    }
  }

  private func performDataSync() async {
    #if DEBUG
    print("🔄 WebSocketManager: Performing data sync via HTTP polling")
    #endif

    // This would typically make HTTP requests to sync data
    // For now, we'll post a notification to trigger app-level sync
    NotificationCenter.default.post(name: .performDataSync, object: nil)
  }
}

// MARK: - Notification Names

extension Notification.Name {
  static let taskUpdated = Notification.Name("taskUpdated")
}
