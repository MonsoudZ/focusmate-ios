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
        InputValidation.isValidName(name)
            && InputValidation.isValidEmail(email)
            && InputValidation.isValidPassword(password)
            && password == confirmPassword
    }

    private var passwordMismatch: Bool {
        !confirmPassword.isEmpty && password != confirmPassword
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
                            TextField("Your name", text: $name)
                                .textInputAutocapitalization(.words)
                                .textContentType(.name)
                                .formFieldStyle()
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
                            if !email.isEmpty && !InputValidation.isValidEmail(email) {
                                Text("Enter a valid email address")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(DS.Colors.error)
                            }
                        }

                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text("Password")
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                            SecureField("Create a password", text: $password)
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
                            SecureField("Confirm your password", text: $confirmPassword)
                                .textContentType(.newPassword)
                                .formFieldStyle()
                            if passwordMismatch {
                                Text("Passwords do not match")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(DS.Colors.error)
                            }
                        }
                    }

                    Button {
                        Task { await register() }
                    } label: {
                        Text(auth.isLoading ? "Creating Account..." : "Create Account")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(IntentiaPrimaryButtonStyle())
                    .disabled(auth.isLoading || !isValid)
                    .padding(.top, DS.Spacing.sm)
                }
                .padding(DS.Spacing.xl)
            }
            .floatingErrorBanner($auth.error) {
                await register()
            }
            .navigationTitle("Create Account")
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

    private func register() async {
        auth.error = nil
        await auth.register(email: email, password: password, name: name)

        if auth.jwt != nil {
            dismiss()
        }
    }
}
