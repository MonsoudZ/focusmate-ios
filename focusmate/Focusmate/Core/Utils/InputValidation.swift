import Foundation

enum InputValidation {
  // MARK: - Email

  static func isValidEmail(_ email: String) -> Bool {
    let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    // No whitespace allowed within the email itself
    guard !trimmed.contains(where: \.isWhitespace) else { return false }
    let parts = trimmed.split(separator: "@")
    guard parts.count == 2, !parts[0].isEmpty else { return false }
    // Domain must have at least two labels (e.g. "example.com"), no empty
    // labels (catches leading/trailing dots), and a TLD of 2+ characters.
    let domainLabels = String(parts[1]).split(separator: ".", omittingEmptySubsequences: false)
    guard domainLabels.count >= 2,
          domainLabels.allSatisfy({ !$0.isEmpty }),
          let tld = domainLabels.last, tld.count >= 2
    else {
      return false
    }
    return true
  }

  // MARK: - Password

  static let minimumPasswordLength = 8

  static func isValidPassword(_ password: String) -> Bool {
    password.count >= self.minimumPasswordLength
  }

  static func passwordError(_ password: String) -> String? {
    if password.isEmpty { return nil } // Don't show error on empty (not yet typed)
    if password.count < self.minimumPasswordLength {
      return "Password must be at least \(self.minimumPasswordLength) characters"
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

  // MARK: - Throwing Validators

  //
  // These replace the ~10 identical `private func validateX` methods scattered
  // across TaskService, InviteService, and FriendService. Each service had its
  // own copy of the same guard-else-throw pattern, differing only in the field name.

  static func requirePositive(_ value: Int, fieldName: String) throws {
    guard value > 0 else {
      throw FocusmateError.validation([fieldName: ["must be a positive number"]], nil)
    }
  }

  static func requireNotEmpty(_ value: String, fieldName: String) throws {
    guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw FocusmateError.validation([fieldName: ["cannot be empty"]], nil)
    }
  }
}
