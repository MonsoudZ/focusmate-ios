import Foundation

actor AuthSession {
    private var jwt: String?
    private var _refreshToken: String?

    func set(token: String) {
        jwt = token
    }

    func setRefreshToken(_ token: String) {
        _refreshToken = token
    }

    func clear() {
        jwt = nil
        _refreshToken = nil
    }

    func access() throws -> String {
        guard let t = jwt else { throw APIError.unauthorized(nil) }
        return t
    }

    func accessRefreshToken() -> String? {
        _refreshToken
    }

    var isLoggedIn: Bool {
        jwt != nil
    }
}
