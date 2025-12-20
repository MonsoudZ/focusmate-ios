import Foundation

enum API {
    static let base: URL = {
        guard let url = URL(string: "https://focusmate-api-production.up.railway.app") else {
            fatalError("Critical: Failed to create base URL")
        }
        return url
    }()

    static func path(_ p: String) -> URL {
        base.appendingPathComponent(p)
    }

    static let webSocketURL: URL = {
        guard let url = URL(string: "wss://focusmate-api-production.up.railway.app/cable") else {
            fatalError("Critical: Failed to create WebSocket URL")
        }
        return url
    }()

    enum Auth {
        static let signIn  = "api/v1/auth/sign_in"
        static let signUp  = "api/v1/auth/sign_up"
        static let signOut = "api/v1/auth/sign_out"
    }

    enum Users {
        static let deviceToken = "api/v1/devices"
    }

    enum Lists {
        static let root = "api/v1/lists"
        static func id(_ id: String) -> String { "api/v1/lists/\(id)" }
        static func tasks(_ listId: String) -> String { "api/v1/lists/\(listId)/tasks" }
        static func task(_ listId: String, _ taskId: String) -> String { "api/v1/lists/\(listId)/tasks/\(taskId)" }
        static func taskAction(_ listId: String, _ taskId: String, _ action: String) -> String {
            "api/v1/lists/\(listId)/tasks/\(taskId)/\(action)"
        }
    }

    enum Tasks {
        static let root = "api/v1/tasks"
    }
}
