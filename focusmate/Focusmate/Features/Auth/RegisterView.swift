import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    private var isValid: Bool {
        InputValidation.isValidName(name)
            && InputValidation.isValidEmail(email)
            && InputValidation.isValidPassword(password)
            && password == confirmPassword
    }

    private var passwordMismatch: Bool {
        !confirmPassword.isEmpty && password != confirmPassword
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.lg) {
                VStack(spacing: DS.Spacing.md) {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .formFieldStyle()

                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .formFieldStyle()

                    if !email.isEmpty && !InputValidation.isValidEmail(email) {
                        Text("Enter a valid email address")
                            .font(.caption)
                            .foregroundStyle(DS.Colors.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                        .formFieldStyle()

                    if let pwError = InputValidation.passwordError(password) {
                        Text(pwError)
                            .font(.caption)
                            .foregroundStyle(DS.Colors.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .formFieldStyle()

                    if passwordMismatch {
                        Text("Passwords do not match")
                            .font(.caption)
                            .foregroundStyle(DS.Colors.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Button {
                    Task { await register() }
                } label: {
                    Text(state.auth.isLoading ? "Creating Account…" : "Create Account")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(IntentiaPrimaryButtonStyle())
                .disabled(state.auth.isLoading || !isValid)

                if let error = state.auth.error {
                    ErrorBanner(
                        error: error,
                        onRetry: { await register() },
                        onDismiss: { state.auth.error = nil }
                    )
                }

                Spacer()
            }
            .padding(DS.Spacing.xl)
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func register() async {
        state.auth.error = nil
        await state.auth.register(email: email, password: password, name: name)

        if state.auth.jwt != nil {
            dismiss()
        }
    }
}
