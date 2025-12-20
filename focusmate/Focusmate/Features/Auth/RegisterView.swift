import SwiftUI

struct RegisterView: View {
  @EnvironmentObject var state: AppState
  @Environment(\.dismiss) var dismiss
  @State private var email = ""
  @State private var password = ""
  @State private var confirmPassword = ""
  @State private var name = ""

  var body: some View {
    VStack(spacing: 16) {
      Text("Create Account").font(.largeTitle.bold())

      TextField("Name", text: self.$name)
        .textInputAutocapitalization(.words)
        .foregroundColor(.black)
        .accentColor(.black)
        .textFieldStyle(.roundedBorder)

      TextField("Email", text: self.$email)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .textContentType(.emailAddress)
        .foregroundColor(.black)
        .accentColor(.black)
        .textFieldStyle(.roundedBorder)

      SecureField("Password", text: self.$password)
        .textContentType(.newPassword)
        .foregroundColor(.black)
        .accentColor(.black)
        .textFieldStyle(.roundedBorder)

      SecureField("Confirm Password", text: self.$confirmPassword)
        .textContentType(.newPassword)
        .foregroundColor(.black)
        .accentColor(.black)
        .textFieldStyle(.roundedBorder)

      Button {
        Task { await self.register() }
      } label: {
        Text(self.state.auth.isLoading ? "Creating Account…" : "Create Account")
          .frame(maxWidth: .infinity)
          .foregroundColor(.white)
      }
      .buttonStyle(.borderedProminent)
      .disabled(self.state.auth.isLoading || self.email.isEmpty || self.password.isEmpty || self.name.isEmpty || self
        .password != self.confirmPassword)

      Button {
        // Navigate back to sign in
        self.state.auth.jwt = nil
        self.state.auth.currentUser = nil
      } label: {
        Text("Back to Sign In")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .disabled(self.state.auth.isLoading)

      if let error = state.auth.error {
        ErrorBanner(
          error: error,
          onRetry: {
            await self.register()
          },
          onDismiss: {
            self.state.auth.error = nil
          }
        )
        .padding(.top, 8)
      }

      Spacer()
    }
    .padding()
  }

  private func register() async {
    Logger.debug("Starting registration...", category: .auth)
    // Clear any previous errors before starting registration
    self.state.auth.error = nil
    await self.state.auth.register(email: self.email, password: self.password, name: self.name)

    // If registration was successful, dismiss the modal
    if self.state.auth.jwt != nil, self.state.auth.currentUser != nil {
      Logger.info("Registration successful, dismissing modal...", category: .auth)
      await MainActor.run {
        self.dismiss()
      }
    }
  }
}
