import Foundation

actor AuthSession {
    private var jwt: String?
    nonisolated private let tokenStorage = TokenStorage()

    func set(token: String) {
        jwt = token
        tokenStorage.token = token
    }

    func clear() {
        jwt = nil
        tokenStorage.token = nil
    }

    func access() throws -> String {
        guard let t = jwt else { throw APIError.unauthorized }
        return t
    }

    var isLoggedIn: Bool {
        jwt != nil
    }

    nonisolated func getTokenSync() -> String? {
        return tokenStorage.token
    }
}

private final class TokenStorage: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var _token: String?

    nonisolated init() {
        _token = nil
    }

    nonisolated var token: String? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _token
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _token = newValue
        }
    }
}
