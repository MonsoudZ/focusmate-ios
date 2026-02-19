@testable import focusmate
import XCTest

final class InputValidationTests: XCTestCase {
  // MARK: - Email Validation

  func testValidEmail() {
    XCTAssertTrue(InputValidation.isValidEmail("user@example.com"))
  }

  func testEmailMissingAtSign() {
    XCTAssertFalse(InputValidation.isValidEmail("userexample.com"))
  }

  func testEmailMissingDotInDomain() {
    XCTAssertFalse(InputValidation.isValidEmail("user@examplecom"))
  }

  func testEmailEmpty() {
    XCTAssertFalse(InputValidation.isValidEmail(""))
  }

  func testEmailWhitespaceOnly() {
    XCTAssertFalse(InputValidation.isValidEmail("   "))
  }

  func testEmailLeadingTrailingSpacesTrimmed() {
    XCTAssertTrue(InputValidation.isValidEmail("  user@example.com  "))
  }

  func testEmailMultipleAtSignsWithContent() {
    // "user@foo@bar.com" splits into 3 parts → invalid
    XCTAssertFalse(InputValidation.isValidEmail("user@foo@bar.com"))
  }

  func testEmailDomainTooShort() {
    // "a." has count 2, below the >= 3 threshold → invalid
    XCTAssertFalse(InputValidation.isValidEmail("user@a."))
  }

  func testEmailMissingLocalPart() {
    XCTAssertFalse(InputValidation.isValidEmail("@example.com"))
  }

  func testEmailWithSpaceInLocalPart() {
    XCTAssertFalse(InputValidation.isValidEmail("hello world@example.com"))
  }

  func testEmailWithLeadingDotInDomain() {
    XCTAssertFalse(InputValidation.isValidEmail("user@.example.com"))
  }

  func testEmailWithTrailingDotInDomain() {
    XCTAssertFalse(InputValidation.isValidEmail("user@example.com."))
  }

  func testEmailWithSingleCharTLD() {
    XCTAssertFalse(InputValidation.isValidEmail("user@example.c"))
  }

  func testEmailWithSubdomain() {
    XCTAssertTrue(InputValidation.isValidEmail("user@mail.example.com"))
  }

  // MARK: - Password Validation

  func testValidPassword() {
    XCTAssertTrue(InputValidation.isValidPassword("password123"))
  }

  func testPasswordTooShort() {
    XCTAssertFalse(InputValidation.isValidPassword("short"))
  }

  func testPasswordEmpty() {
    XCTAssertFalse(InputValidation.isValidPassword(""))
  }

  func testPasswordExactlyMinimumLength() {
    let password = String(repeating: "a", count: InputValidation.minimumPasswordLength)
    XCTAssertTrue(InputValidation.isValidPassword(password))
  }

  func testPasswordOneCharBelowMinimum() {
    let password = String(repeating: "a", count: InputValidation.minimumPasswordLength - 1)
    XCTAssertFalse(InputValidation.isValidPassword(password))
  }

  // MARK: - Password Error

  func testPasswordErrorNilWhenEmpty() {
    XCTAssertNil(InputValidation.passwordError(""))
  }

  func testPasswordErrorNilWhenValid() {
    XCTAssertNil(InputValidation.passwordError("password123"))
  }

  func testPasswordErrorMessageWhenTooShort() {
    let error = InputValidation.passwordError("short")
    guard let error else {
      XCTFail("Expected validation error for short password but got nil")
      return
    }
    XCTAssertTrue(error.contains("at least"), "Error should mention 'at least'")
    XCTAssertTrue(error.contains("\(InputValidation.minimumPasswordLength)"), "Error should mention minimum length")
  }

  func testPasswordErrorNilAtExactMinimum() {
    let password = String(repeating: "a", count: InputValidation.minimumPasswordLength)
    XCTAssertNil(InputValidation.passwordError(password))
  }

  // MARK: - Name Validation

  func testValidName() {
    XCTAssertTrue(InputValidation.isValidName("John Doe"))
  }

  func testNameEmpty() {
    XCTAssertFalse(InputValidation.isValidName(""))
  }

  func testNameWhitespaceOnly() {
    XCTAssertFalse(InputValidation.isValidName("   "))
  }

  // MARK: - Title Validation

  func testValidTitle() {
    XCTAssertTrue(InputValidation.isValidTitle("Buy groceries"))
  }

  func testTitleEmpty() {
    XCTAssertFalse(InputValidation.isValidTitle(""))
  }

  func testTitleExceedsMaxLength() {
    let longTitle = String(repeating: "a", count: 501)
    XCTAssertFalse(InputValidation.isValidTitle(longTitle))
  }

  func testTitleExactlyMaxLength() {
    let title = String(repeating: "a", count: 500)
    XCTAssertTrue(InputValidation.isValidTitle(title))
  }

  func testTitleCustomMaxLength() {
    let title = String(repeating: "a", count: 51)
    XCTAssertFalse(InputValidation.isValidTitle(title, maxLength: 50))
  }

  func testTitleCustomMaxLengthValid() {
    let title = String(repeating: "a", count: 50)
    XCTAssertTrue(InputValidation.isValidTitle(title, maxLength: 50))
  }

  func testTitleWhitespaceOnly() {
    XCTAssertFalse(InputValidation.isValidTitle("   "))
  }
}
