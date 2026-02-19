import SwiftUI

struct RegisterView: View {
  @EnvironmentObject var state: AppState
  @Environment(AuthStore.self) var auth
  @Environment(\.dismiss) var dismiss
  @State private var name = ""
  @State private var email = ""
  @State private var password = ""
  @State private var confirmPassword = ""

  private var isValid: Bool {
    InputValidation.isValidName(self.name)
      && InputValidation.isValidEmail(self.email)
      && InputValidation.isValidPassword(self.password)
      && self.password == self.confirmPassword
  }

  private var passwordMismatch: Bool {
    !self.confirmPassword.isEmpty && self.password != self.confirmPassword
  }

  var body: some View {
    @Bindable var auth = auth
    NavigationStack {
      ScrollView {
        VStack(spacing: DS.Spacing.lg) {
          // Form fields
          VStack(spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
              Text("Name")
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
              TextField("Your name", text: self.$name)
                .textInputAutocapitalization(.words)
                .textContentType(.name)
                .formFieldStyle()
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
              Text("Email")
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
              TextField("your@email.com", text: self.$email)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .formFieldStyle()
              if !self.email.isEmpty, !InputValidation.isValidEmail(self.email) {
                Text("Enter a valid email address")
                  .font(DS.Typography.caption)
                  .foregroundStyle(DS.Colors.error)
              }
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
              Text("Password")
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
              SecureField("Create a password", text: self.$password)
                .textContentType(.newPassword)
                .formFieldStyle()
              if let pwError = InputValidation.passwordError(password) {
                Text(pwError)
                  .font(DS.Typography.caption)
                  .foregroundStyle(DS.Colors.error)
              }
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
              Text("Confirm Password")
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
              SecureField("Confirm your password", text: self.$confirmPassword)
                .textContentType(.newPassword)
                .formFieldStyle()
              if self.passwordMismatch {
                Text("Passwords do not match")
                  .font(DS.Typography.caption)
                  .foregroundStyle(DS.Colors.error)
              }
            }
          }

          Button {
            Task { await self.register() }
          } label: {
            Text(auth.isLoading ? "Creating Account..." : "Create Account")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(IntentiaPrimaryButtonStyle())
          .disabled(auth.isLoading || !self.isValid)
          .padding(.top, DS.Spacing.sm)
        }
        .padding(DS.Spacing.xl)
      }
      .floatingErrorBanner($auth.error) {
        await self.register()
      }
      .navigationTitle("Create Account")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            self.dismiss()
          }
          .buttonStyle(IntentiaToolbarCancelStyle())
        }
      }
    }
  }

  private func register() async {
    self.auth.error = nil
    await self.auth.register(email: self.email, password: self.password, name: self.name)

    if self.auth.jwt != nil {
      self.dismiss()
    }
  }
}
