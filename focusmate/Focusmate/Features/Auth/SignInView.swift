import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var state: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var showingRegister = false
    @State private var showingForgotPassword = false
    @State private var showingInviteCode = false

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            // Brand
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: "target")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(DS.Colors.accent)

                Text("Intentia")
                    .font(DS.Typography.largeTitle)
                    .foregroundStyle(DS.Colors.accent)

                Text("Intentional focus, real accountability")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, DS.Spacing.lg)

            // Apple Sign In Button
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { result in
                state.auth.handleAppleSignIn(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))

            DSDivider("or")

            // Email/Password fields
            VStack(spacing: DS.Spacing.md) {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
                    .font(DS.Typography.body)
                    .padding(DS.Spacing.md)
                    .background(DS.Colors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .font(DS.Typography.body)
                    .padding(DS.Spacing.md)
                    .background(DS.Colors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )

                HStack {
                    Spacer()
                    Button("Forgot Password?") {
                        showingForgotPassword = true
                    }
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(DS.Colors.accent)
                }
            }

            VStack(spacing: DS.Spacing.sm) {
                Button {
                    Task { await state.auth.signIn(email: email, password: password) }
                } label: {
                    Text(state.auth.isLoading ? "Signing in..." : "Sign In")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(IntentiaPrimaryButtonStyle())
                .disabled(state.auth.isLoading || !InputValidation.isValidEmail(email) || password.isEmpty)

                Button {
                    showingRegister = true
                } label: {
                    Text("Create Account")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(IntentiaSecondaryButtonStyle())
                .disabled(state.auth.isLoading)
            }

            DSDivider("or")

            Button {
                showingInviteCode = true
            } label: {
                Label("I have an invite code", systemImage: "link.badge.plus")
            }
            .font(DS.Typography.body)
            .foregroundStyle(DS.Colors.accent)

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
        .padding(DS.Spacing.xl)
        .surfaceBackground()
        .sheet(isPresented: $showingRegister) {
            RegisterView()
        }
        .sheet(isPresented: $showingForgotPassword) {
            ForgotPasswordView()
        }
        .sheet(isPresented: $showingInviteCode) {
            EnterInviteCodeView(
                inviteService: state.inviteService,
                onAccepted: { _ in }
            )
        }
    }
}
