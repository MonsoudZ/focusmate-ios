import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var state: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var showingRegister = false
    @State private var showingForgotPassword = false

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()

            Text("Intentia")
                .font(DesignSystem.Typography.largeTitle)

            // Apple Sign In Button
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { result in
                state.auth.handleAppleSignIn(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)

            DSDivider("or")

            // Email/Password fields
            VStack(spacing: DesignSystem.Spacing.md) {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .textFieldStyle(.roundedBorder)
                
                HStack {
                    Spacer()
                    Button("Forgot Password?") {
                        showingForgotPassword = true
                    }
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.primary)
                }
            }

            VStack(spacing: DesignSystem.Spacing.sm) {
                Button {
                    Task { await state.auth.signIn(email: email, password: password) }
                } label: {
                    Text(state.auth.isLoading ? "Signing in…" : "Sign In")
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.auth.isLoading || email.isEmpty || password.isEmpty)

                Button {
                    showingRegister = true
                } label: {
                    Text("Create Account")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(state.auth.isLoading)
            }

            if let error = state.auth.error {
                ErrorBanner(
                    error: error,
                    onRetry: {
                        await state.auth.signIn(email: email, password: password)
                    },
                    onDismiss: {
                        state.auth.error = nil
                    }
                )
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.padding)
        .sheet(isPresented: $showingRegister) {
            RegisterView()
        }
        .sheet(isPresented: $showingForgotPassword) {
            ForgotPasswordView()
        }
    }
}
