import Foundation
import Combine

class WebSocketManager: ObservableObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var reconnectTimer: Timer?
    private var isConnected = false
    
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var lastError: String?
    
    enum ConnectionStatus {
        case connected
        case connecting
        case disconnected
        case error(String)
    }
    
    // MARK: - Connection Management
    
    func connect(with token: String) {
        guard !isConnected else { return }
        
        connectionStatus = .connecting
        
        // Construct the WebSocket URL with JWT token
        guard let baseURL = URL(string: "wss://untampered-jong-harshly.ngrok-free.dev/cable") else {
            connectionStatus = .error("Invalid WebSocket URL")
            return
        }
        
        var urlComponents = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        urlComponents?.queryItems = [URLQueryItem(name: "token", value: token)]
        
        guard let webSocketURL = urlComponents?.url else {
            connectionStatus = .error("Failed to construct WebSocket URL")
            return
        }
        
        print("🔌 WebSocketManager: Connecting to \(webSocketURL)")
        
        // Create URLSession with custom headers
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "ngrok-skip-browser-warning": "true"
        ]
        
        urlSession = URLSession(configuration: config)
        webSocketTask = urlSession?.webSocketTask(with: webSocketURL)
        
        startListening()
        sendWelcomeMessage()
    }
    
    func disconnect() {
        print("🔌 WebSocketManager: Disconnecting")
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession = nil
        isConnected = false
        connectionStatus = .disconnected
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
    
    // MARK: - Message Handling
    
    private func startListening() {
        webSocketTask?.resume()
        receiveMessage()
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                self?.receiveMessage() // Continue listening
            case .failure(let error):
                print("🔌 WebSocketManager: Receive error: \(error)")
                self?.handleConnectionError(error)
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            print("🔌 WebSocketManager: Received: \(text)")
            handleTextMessage(text)
        case .data(let data):
            print("🔌 WebSocketManager: Received data: \(data.count) bytes")
            if let text = String(data: data, encoding: .utf8) {
                handleTextMessage(text)
            }
        @unknown default:
            print("🔌 WebSocketManager: Unknown message type")
        }
    }
    
    private func handleTextMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        
        do {
            // Parse ActionCable message format
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                handleActionCableMessage(json)
            }
        } catch {
            print("🔌 WebSocketManager: JSON parsing error: \(error)")
        }
    }
    
    private func handleActionCableMessage(_ message: [String: Any]) {
        // Handle different ActionCable message types
        if let type = message["type"] as? String {
            switch type {
            case "welcome":
                handleWelcome()
            case "ping":
                handlePing()
            case "confirm_subscription":
                handleSubscriptionConfirmation()
            case "reject_subscription":
                handleSubscriptionRejection()
            default:
                print("🔌 WebSocketManager: Unknown message type: \(type)")
            }
        }
        
        // Handle data messages (task updates)
        if let message = message["message"] as? [String: Any] {
            handleTaskUpdate(message)
        }
    }
    
    private func handleWelcome() {
        print("🔌 WebSocketManager: Welcome message received")
        isConnected = true
        connectionStatus = .connected
        subscribeToTaskUpdates()
    }
    
    private func handlePing() {
        // Respond to ping with pong
        sendPong()
    }
    
    private func handleSubscriptionConfirmation() {
        print("🔌 WebSocketManager: Subscription confirmed")
    }
    
    private func handleSubscriptionRejection() {
        print("🔌 WebSocketManager: Subscription rejected")
        connectionStatus = .error("Subscription rejected")
    }
    
    private func handleTaskUpdate(_ message: [String: Any]) {
        print("🔌 WebSocketManager: Task update received: \(message)")
        
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
            "identifier": "{\"channel\":\"TaskChannel\"}"
        ]
        sendMessage(welcomeMessage)
    }
    
    private func subscribeToTaskUpdates() {
        let subscribeMessage = [
            "command": "subscribe",
            "identifier": "{\"channel\":\"TaskChannel\"}"
        ]
        sendMessage(subscribeMessage)
    }
    
    private func sendPong() {
        let pongMessage = [
            "command": "message",
            "identifier": "{\"channel\":\"TaskChannel\"}",
            "data": "{\"action\":\"pong\"}"
        ]
        sendMessage(pongMessage)
    }
    
    private func sendMessage(_ message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: data, encoding: .utf8) else {
            print("🔌 WebSocketManager: Failed to serialize message")
            return
        }
        
        webSocketTask?.send(.string(jsonString)) { error in
            if let error = error {
                print("🔌 WebSocketManager: Send error: \(error)")
            }
        }
    }
    
    // MARK: - Error Handling
    
    private func handleConnectionError(_ error: Error) {
        print("🔌 WebSocketManager: Connection error: \(error)")
        isConnected = false
        connectionStatus = .error(error.localizedDescription)
        lastError = error.localizedDescription
        
        // Attempt to reconnect after a delay
        scheduleReconnect()
    }
    
    private func scheduleReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            print("🔌 WebSocketManager: Attempting to reconnect...")
            // Note: Would need the token to reconnect
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let taskUpdated = Notification.Name("taskUpdated")
}
