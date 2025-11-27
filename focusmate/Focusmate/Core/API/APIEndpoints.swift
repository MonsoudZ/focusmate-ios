import Foundation

enum API {
    static let base: URL = {
        // Read API_BASE_URL from Info.plist (configured via xcconfig files)
        if let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           let url = URL(string: urlString) {
            return url
        }

        // Fallback: Try environment variable for CI/CD or testing
        if let stagingURL = ProcessInfo.processInfo.environment["STAGING_API_URL"],
           !stagingURL.isEmpty,
           let url = URL(string: stagingURL) {
            return URL(string: stagingURL)!
        }

        // Last resort fallback for development (should never happen with proper xcconfig setup)
        #if DEBUG
        print("⚠️ WARNING: API_BASE_URL not found in Info.plist, using localhost fallback")
        #endif
        return URL(string: "http://localhost:3000")!
    }()

    /// WebSocket (ActionCable) URL - read from Info.plist or derived from base URL
    static let webSocketURL: URL = {
        // First try to read CABLE_URL directly from Info.plist (configured via xcconfig)
        if let cableURLString = Bundle.main.object(forInfoDictionaryKey: "CABLE_URL") as? String,
           let url = URL(string: cableURLString) {
            return url
        }

        // Fallback: Derive from base URL
        var urlString = base.absoluteString

        // Replace http:// with ws:// and https:// with wss://
        if urlString.hasPrefix("https://") {
            urlString = urlString.replacingOccurrences(of: "https://", with: "wss://")
        } else if urlString.hasPrefix("http://") {
            urlString = urlString.replacingOccurrences(of: "http://", with: "ws://")
        }

        // Remove /api/v1 suffix if present and add /cable
        if urlString.hasSuffix("/api/v1") {
            urlString = String(urlString.dropLast(7))
        }
        urlString += "/cable"

        return URL(string: urlString)!
    }()

    enum Auth {
        static let signIn  = "/api/v1/auth/sign_in"
        static let signUp  = "/api/v1/auth/sign_up"
        static let signOut = "/api/v1/auth/sign_out"
    }

    enum Users {
        static let deviceToken = "/api/v1/users/device_token" // PATCH
    }

    enum Lists {
        static let root = "/api/v1/lists"
        static func id(_ id: String) -> String { "/api/v1/lists/\(id)" }
        static func tasks(_ listId: String) -> String { "/api/v1/lists/\(listId)/tasks" }
        static func task(_ listId: String, _ taskId: String) -> String { "/api/v1/lists/\(listId)/tasks/\(taskId)" }
        static func taskAction(_ listId: String, _ taskId: String, _ action: String) -> String {
            "/api/v1/lists/\(listId)/tasks/\(taskId)/\(action)" // complete | uncomplete | reassign
        }
    }

    enum DashTasks {
        static let all      = "/api/v1/tasks/all_tasks"
        static let blocking = "/api/v1/tasks/blocking"
        static let awaiting = "/api/v1/tasks/awaiting_explanation"
        static let overdue  = "/api/v1/tasks/overdue"
    }
}
