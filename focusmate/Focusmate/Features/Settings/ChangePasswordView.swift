import SwiftUI

struct ChangePasswordView: View {
  @Environment(\.dismiss) private var dismiss

  @State private var viewModel: ChangePasswordViewModel

  init(apiClient: APIClient) {
    _viewModel = State(initialValue: ChangePasswordViewModel(apiClient: apiClient))
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          SecureField("Current Password", text: self.$viewModel.currentPassword)
            .textContentType(.password)
        } footer: {
          HStack {
            Text("Enter your current password to verify your identity.")
            Spacer()
            Button("Forgot?") {
              if let url = URL(string: "https://intentia.app/reset-password") {
                UIApplication.shared.open(url)
              }
            }
            .font(.subheadline)
          }
        }

        Section {
          SecureField("New Password", text: self.$viewModel.newPassword)
            .textContentType(.newPassword)

          SecureField("Confirm New Password", text: self.$viewModel.confirmPassword)
            .textContentType(.newPassword)
        } footer: {
          if self.viewModel.newPassword.count > 0, self.viewModel.newPassword.count < 8 {
            Text("Password must be at least 8 characters.")
              .foregroundColor(.red)
          } else if !self.viewModel.confirmPassword.isEmpty,
                    self.viewModel.newPassword != self.viewModel.confirmPassword
          {
            Text("Passwords don't match.")
              .foregroundColor(.red)
          }
        }
      }
      .surfaceFormBackground()
      .navigationTitle("Change Password")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            self.dismiss()
          }
          .buttonStyle(IntentiaToolbarCancelStyle())
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            Task { await self.viewModel.changePassword() }
          }
          .buttonStyle(IntentiaToolbarPrimaryStyle())
          .disabled(!self.viewModel.isValid || self.viewModel.isLoading)
        }
      }
      .overlay {
        if self.viewModel.isLoading {
          ProgressView()
            .scaleEffect(1.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.2))
        }
      }
      .floatingErrorBanner(self.$viewModel.error)
      .alert("Success", isPresented: self.$viewModel.showSuccess) {
        Button("OK") { self.dismiss() }
      } message: {
        Text("Your password has been changed.")
      }
    }
  }
}

struct ChangePasswordRequest: Encodable {
  let currentPassword: String
  let password: String
  let passwordConfirmation: String

  enum CodingKeys: String, CodingKey {
    case currentPassword = "current_password"
    case password
    case passwordConfirmation = "password_confirmation"
  }
}
