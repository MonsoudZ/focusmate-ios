import Foundation

protocol KeychainManaging {
    func save(token: String)
    func load() -> String?
    func clear()
}

extension KeychainManager: KeychainManaging {}
