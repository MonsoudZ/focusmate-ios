import Foundation

enum API {
    static let base: URL = {
        // Try to get staging URL from environment, fallback to localhost for development
        if let stagingURL = ProcessInfo.processInfo.environment["STAGING_API_URL"], !stagingURL.isEmpty {
            return URL(string: stagingURL)!
        } else {
            // Fallback to localhost for development
            return URL(string: "http://localhost:3000")!
        }
    }()
    
    // Mock mode for testing when API is not available
    static let isMockMode: Bool = {
        ProcessInfo.processInfo.environment["MOCK_API"] == "true"
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
