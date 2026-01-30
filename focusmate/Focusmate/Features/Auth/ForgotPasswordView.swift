import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var submitted = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    if submitted {
                        successView
                    } else {
                        formView
                    }
                }
                .padding(DS.Spacing.xl)
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
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
                TextField("your@email.com", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .formFieldStyle()
            }

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
            }
            .buttonStyle(IntentiaPrimaryButtonStyle())
            .disabled(state.auth.isLoading || !InputValidation.isValidEmail(email))

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

                Text("We've sent password reset instructions to \(email)")
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                dismiss()
            } label: {
                Text("Back to Sign In")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(IntentiaPrimaryButtonStyle())

            Spacer(minLength: DS.Spacing.xxxl)
        }
    }
}
