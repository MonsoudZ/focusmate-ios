import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var submitted = false

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.lg) {
                if submitted {
                    successView
                } else {
                    formView
                }
            }
            .padding(DesignSystem.Spacing.padding)
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var formView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()

            Image(systemName: "lock.rotation")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.primary)

            Text("Forgot your password?")
                .font(DesignSystem.Typography.title2)

            Text("Enter your email and we'll send you instructions to reset your password.")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)

            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textFieldStyle(.roundedBorder)

            Button {
                Task {
                    await state.auth.forgotPassword(email: email)
                    if state.auth.error == nil {
                        submitted = true
                    }
                }
            } label: {
                Text(state.auth.isLoading ? "Sending..." : "Send Reset Link")
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
            }
            .buttonStyle(.borderedProminent)
            .disabled(state.auth.isLoading || email.isEmpty)

            if let error = state.auth.error {
                ErrorBanner(
                    error: error,
                    onRetry: {
                        await state.auth.forgotPassword(email: email)
                    },
                    onDismiss: {
                        state.auth.error = nil
                    }
                )
            }

            Spacer()
        }
    }

    private var successView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()

            Image(systemName: "envelope.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.success)

            Text("Check your email")
                .font(DesignSystem.Typography.title2)

            Text("We've sent password reset instructions to \(email)")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                dismiss()
            } label: {
                Text("Back to Sign In")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
    }
}
