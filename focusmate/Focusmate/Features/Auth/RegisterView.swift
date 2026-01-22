import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    private var isValid: Bool {
        !name.isEmpty && !email.isEmpty && !password.isEmpty && password == confirmPassword
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.lg) {
                VStack(spacing: DS.Spacing.md) {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .textFieldStyle(.roundedBorder)

                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .textFieldStyle(.roundedBorder)
                }

                Button {
                    Task { await register() }
                } label: {
                    Text(state.auth.isLoading ? "Creating Account…" : "Create Account")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
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
