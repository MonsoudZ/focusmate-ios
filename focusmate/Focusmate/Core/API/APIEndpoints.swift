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

        /// Pre-validated base URL. Parsed once at first access, thread-safe.
        var baseURL: URL {
            switch self {
            case .development: return Self.validated.development.base
            case .staging:     return Self.validated.staging.base
            case .production:  return Self.validated.production.base
            }
        }

        /// Pre-validated WebSocket URL. Parsed once at first access, thread-safe.
        var webSocketURL: URL {
            switch self {
            case .development: return Self.validated.development.webSocket
            case .staging:     return Self.validated.staging.webSocket
            case .production:  return Self.validated.production.webSocket
            }
        }

        // MARK: - URL Validation Cache

        private struct URLs {
            let base: URL
            let webSocket: URL
        }

        private struct ValidatedURLs {
            let development: URLs
            let staging: URLs
            let production: URLs
        }

        /// All environment URLs validated once at first access.
        /// Uses static let for thread-safe lazy initialization.
        /// Logs error and uses fallback URL if validation fails (should never happen with hardcoded URLs).
        private static let validated: ValidatedURLs = {
            // Fallback URL for catastrophic failure (should never be reached).
            // Force unwrap is safe here - "https://example.com" is a valid URL constant.
            // swiftlint:disable:next force_unwrapping
            let fallbackURL = URL(string: "https://example.com")!

            func validate(_ env: Environment) -> URLs {
                guard let base = URL(string: env.baseURLString) else {
                    assertionFailure("Invalid base URL for \(env): \(env.baseURLString)")
                    Logger.error("Invalid base URL for \(env): \(env.baseURLString)", category: .api)
                    return URLs(base: fallbackURL, webSocket: fallbackURL)
                }
                guard let webSocket = URL(string: env.webSocketURLString) else {
                    assertionFailure("Invalid WebSocket URL for \(env): \(env.webSocketURLString)")
                    Logger.error("Invalid WebSocket URL for \(env): \(env.webSocketURLString)", category: .api)
                    return URLs(base: base, webSocket: fallbackURL)
                }
                return URLs(base: base, webSocket: webSocket)
            }
            return ValidatedURLs(
                development: validate(.development),
                staging: validate(.staging),
                production: validate(.production)
            )
        }()
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

    static var base: URL { current.baseURL }

    static var webSocketURL: URL { current.webSocketURL }

    static func path(_ p: String) -> URL {
        let normalized = p.hasPrefix("/") ? String(p.dropFirst()) : p
        return base.appendingPathComponent(normalized)
    }

    enum Auth {
        static let signIn   = "api/v1/auth/sign_in"
        static let signUp   = "api/v1/auth/sign_up"
        static let signOut  = "api/v1/auth/sign_out"
        static let apple    = "api/v1/auth/apple"
        static let password = "api/v1/auth/password"
        static let refresh  = "api/v1/auth/refresh"
    }

    enum Users {
        static let deviceToken = "api/v1/devices"
        static let profile = "api/v1/users/profile"
        static let password = "api/v1/users/profile/password"
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
        static func subtask(_ listId: String, _ taskId: String, _ subtaskId: String) -> String {
            "api/v1/lists/\(listId)/tasks/\(taskId)/subtasks/\(subtaskId)"
        }
        static func subtaskAction(_ listId: String, _ taskId: String, _ subtaskId: String, _ action: String) -> String {
            "api/v1/lists/\(listId)/tasks/\(taskId)/subtasks/\(subtaskId)/\(action)"
        }
        static func invites(_ listId: String) -> String { "api/v1/lists/\(listId)/invites" }
        static func invite(_ listId: String, _ inviteId: String) -> String { "api/v1/lists/\(listId)/invites/\(inviteId)" }
    }

    enum Invites {
        static func preview(_ code: String) -> String { "api/v1/invites/\(code)" }
        static func accept(_ code: String) -> String { "api/v1/invites/\(code)/accept" }
    }

    enum Tasks {
        static let root = "api/v1/tasks"
        static let search = "api/v1/tasks/search"
        static func id(_ id: String) -> String { "api/v1/tasks/\(id)" }
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

    enum Friends {
        static let list = "api/v1/friends"
        static func friend(_ id: String) -> String { "api/v1/friends/\(id)" }
    }

}
