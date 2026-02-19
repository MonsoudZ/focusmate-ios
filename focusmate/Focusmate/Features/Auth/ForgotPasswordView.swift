import SwiftUI

struct ForgotPasswordView: View {
  @EnvironmentObject var state: AppState
  @Environment(AuthStore.self) var auth
  @Environment(\.dismiss) var dismiss
  @State private var email = ""
  @State private var submitted = false

  var body: some View {
    @Bindable var auth = auth
    NavigationStack {
      ScrollView {
        VStack(spacing: DS.Spacing.lg) {
          if self.submitted {
            self.successView
          } else {
            self.formView
          }
        }
        .padding(DS.Spacing.xl)
      }
      .floatingErrorBanner($auth.error) {
        await auth.forgotPassword(email: self.email)
      }
      .navigationTitle("Reset Password")
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

  private var formView: some View {
    VStack(spacing: DS.Spacing.xl) {
      Spacer(minLength: DS.Spacing.xxxl)

      Image(systemName: "lock.rotation")
        .font(.system(size: DS.Size.iconJumbo, weight: .light))
        .foregroundStyle(DS.Colors.accent)

      VStack(spacing: DS.Spacing.sm) {
        Text("Forgot your password?")
          .font(DS.Typography.title2)

        Text("Enter your email and we'll send you instructions to reset your password.")
          .font(DS.Typography.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
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
      }

      Button {
        Task {
          await self.auth.forgotPassword(email: self.email)
          if self.auth.error == nil {
            self.submitted = true
          }
        }
      } label: {
        Text(self.auth.isLoading ? "Sending..." : "Send Reset Link")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(IntentiaPrimaryButtonStyle())
      .disabled(self.auth.isLoading || !InputValidation.isValidEmail(self.email))

      Spacer(minLength: DS.Spacing.xxxl)
    }
  }

  private var successView: some View {
    VStack(spacing: DS.Spacing.xl) {
      Spacer(minLength: DS.Spacing.xxxl)

      Image(systemName: "envelope.circle.fill")
        .font(.system(size: DS.Size.iconJumbo, weight: .light))
        .foregroundStyle(DS.Colors.success)

      VStack(spacing: DS.Spacing.sm) {
        Text("Check your email")
          .font(DS.Typography.title2)

        Text("We've sent password reset instructions to \(self.email)")
          .font(DS.Typography.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }

      Button {
        self.dismiss()
      } label: {
        Text("Back to Sign In")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(IntentiaPrimaryButtonStyle())

      Spacer(minLength: DS.Spacing.xxxl)
    }
  }
}
