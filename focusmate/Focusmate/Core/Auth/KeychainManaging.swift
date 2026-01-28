import Foundation

protocol KeychainManaging {
    func save(token: String)
    func load() -> String?
    func clear()

    func save(refreshToken: String)
    func loadRefreshToken() -> String?
    func clearRefreshToken()
}

extension KeychainManager: KeychainManaging {}
