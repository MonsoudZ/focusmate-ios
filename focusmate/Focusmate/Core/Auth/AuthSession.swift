import Foundation

actor AuthSession {
    private var jwt: String?

    func set(token: String) {
        jwt = token
    }

    func clear() {
        jwt = nil
    }

    func access() throws -> String {
        guard let t = jwt else { throw APIError.unauthorized }
        return t
    }

    var isLoggedIn: Bool {
        jwt != nil
    }
}
