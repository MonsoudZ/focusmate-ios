import Foundation

protocol KeychainManaging {
    @discardableResult func save(token: String) -> Bool
    func load() -> String?
    func clear()

    @discardableResult func save(refreshToken: String) -> Bool
    func loadRefreshToken() -> String?
    func clearRefreshToken()
}

extension KeychainManager: KeychainManaging {}
