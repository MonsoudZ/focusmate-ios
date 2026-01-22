import Foundation

enum API {

    enum Environment: String {
        case development
        case staging
        case production

        var baseURLString: String {
            switch self {
            case .development: return "http://localhost:3000"
            case .staging:     return "https://focusmate-api-focusmate-api-staging.up.railway.app"
            case .production:  return "https://focusmate-api-production.up.railway.app"
            }
        }

        var webSocketURLString: String {
            switch self {
            case .development: return "ws://localhost:3000/cable"
            case .staging:     return "wss://focusmate-api-focusmate-api-staging.up.railway.app/cable"
            case .production:  return "wss://focusmate-api-production.up.railway.app/cable"
            }
        }
    }

    static var current: Environment {
        if let raw = AppSettings.shared.apiEnvironmentOverrideRawValue,
           let override = Environment(rawValue: raw) {
            return override
        }

        #if DEBUG
            #if targetEnvironment(simulator)
                return .development
            #else
                return .staging
            #endif
        #else
            return .production
        #endif
    }

    static var base: URL {
        guard let url = URL(string: current.baseURLString) else {
            fatalError("Critical: Failed to create base URL")
        }
        return url
    }

    static func path(_ p: String) -> URL {
        let normalized = p.hasPrefix("/") ? String(p.dropFirst()) : p
        return base.appendingPathComponent(normalized)
    }

    static var webSocketURL: URL {
        guard let url = URL(string: current.webSocketURLString) else {
            fatalError("Critical: Failed to create WebSocket URL")
        }
        return url
    }

    enum Auth {
        static let signIn  = "api/v1/auth/sign_in"
        static let signUp  = "api/v1/auth/sign_up"
        static let signOut = "api/v1/auth/sign_out"
    }

    enum Users {
        static let deviceToken = "api/v1/devices"
        static let profile = "api/v1/users/profile"
        static let password = "api/v1/users/me/password"
    }

    enum Lists {
        static let root = "api/v1/lists"
        static func id(_ id: String) -> String { "api/v1/lists/\(id)" }
        static func tasks(_ listId: String) -> String { "api/v1/lists/\(listId)/tasks" }
        static func task(_ listId: String, _ taskId: String) -> String { "api/v1/lists/\(listId)/tasks/\(taskId)" }
        static func taskAction(_ listId: String, _ taskId: String, _ action: String) -> String {
            "api/v1/lists/\(listId)/tasks/\(taskId)/\(action)"
        }
        static func tasksReorder(_ listId: String) -> String { "api/v1/lists/\(listId)/tasks/reorder" }
        static func memberships(_ listId: String) -> String { "api/v1/lists/\(listId)/memberships" }
        static func membership(_ listId: String, _ membershipId: String) -> String { "api/v1/lists/\(listId)/memberships/\(membershipId)" }
        static func subtasks(_ listId: String, _ taskId: String) -> String {
            "api/v1/lists/\(listId)/tasks/\(taskId)/subtasks"
        }
    }

    enum Tasks {
        static let root = "api/v1/tasks"
        static let search = "api/v1/tasks/search"
    }

    enum Today {
        static let root = "api/v1/today"
    }

    enum Tags {
        static let root = "api/v1/tags"
        static func id(_ id: String) -> String { "api/v1/tags/\(id)" }
    }
    enum Analytics {
        static let appOpened = "api/v1/analytics/app_opened"
    }

}
