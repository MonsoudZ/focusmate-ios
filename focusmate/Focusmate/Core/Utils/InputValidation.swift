import Foundation

enum InputValidation {

    // MARK: - Email

    static func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        // Simple check: contains @ with text on both sides and a dot in the domain.
        let parts = trimmed.split(separator: "@")
        guard parts.count == 2,
              !parts[0].isEmpty,
              parts[1].contains("."),
              parts[1].count >= 3 else {
            return false
        }
        return true
    }

    // MARK: - Password

    static let minimumPasswordLength = 8

    static func isValidPassword(_ password: String) -> Bool {
        password.count >= minimumPasswordLength
    }

    static func passwordError(_ password: String) -> String? {
        if password.isEmpty { return nil } // Don't show error on empty (not yet typed)
        if password.count < minimumPasswordLength {
            return "Password must be at least \(minimumPasswordLength) characters"
        }
        return nil
    }

    // MARK: - Name / Title

    static func isValidName(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func isValidTitle(_ title: String, maxLength: Int = 500) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= maxLength
    }
}
