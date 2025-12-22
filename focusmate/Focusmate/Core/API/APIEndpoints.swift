import Foundation

enum API {
    
    // MARK: - Environment Configuration
    
    enum Environment {
        case development
        case staging
        case production
        
        var baseURLString: String {
            switch self {
            case .development:
                return "http://localhost:3000"
            case .staging:
                return "https://focusmate-api-focusmate-api-staging.up.railway.app"
            case .production:
                return "https://focusmate-api-production.up.railway.app"
            }
        }
        
        var webSocketURLString: String {
            switch self {
            case .development:
                return "ws://localhost:3000/cable"
            case .staging:
                return "wss://focusmate-api-focusmate-api-staging.up.railway.app/cable"
            case .production:
                return "wss://focusmate-api-production.up.railway.app/cable"
            }
        }
    }
    
    // MARK: - Current Environment
    
    static var current: Environment {
        #if DEBUG
        return .staging
        #else
        return .production
        #endif
    }
    
    // MARK: - Base URLs
    
    static let base: URL = {
        guard let url = URL(string: current.baseURLString) else {
            fatalError("Critical: Failed to create base URL")
        }
        return url
    }()

    static func path(_ p: String) -> URL {
        base.appendingPathComponent(p)
    }

    static let webSocketURL: URL = {
        guard let url = URL(string: current.webSocketURLString) else {
            fatalError("Critical: Failed to create WebSocket URL")
        }
        return url
    }()

    // MARK: - Endpoints

    enum Auth {
        static let signIn  = "api/v1/auth/sign_in"
        static let signUp  = "api/v1/auth/sign_up"
        static let signOut = "api/v1/auth/sign_out"
    }

    enum Users {
        static let deviceToken = "api/v1/devices"
        static let profile = "api/v1/users/profile"
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
    
    enum Today {
        static let root = "api/v1/today"
    }
}
