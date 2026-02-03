import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.router) private var router
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                Spacer(minLength: DS.Spacing.xxxl)

                // Brand
                VStack(spacing: DS.Spacing.md) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: DS.Size.logo, height: DS.Size.logo)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))

                    Text("Intentia")
                        .font(DS.Typography.largeTitle)
                        .foregroundStyle(DS.Colors.accent)

                    Text("Intentional focus, real accountability")
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, DS.Spacing.xl)

                // Email/Password fields
                VStack(spacing: DS.Spacing.md) {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .formFieldStyle()

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .formFieldStyle()
                }

                // Sign In button
                Button {
                    Task { await state.auth.signIn(email: email, password: password) }
                } label: {
                    Text(state.auth.isLoading ? "Signing in..." : "Sign In")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(IntentiaPrimaryButtonStyle())
                .disabled(state.auth.isLoading || !InputValidation.isValidEmail(email) || password.isEmpty)

                // Forgot password link
                Button("Forgot Password?") {
                    router.present(.forgotPassword)
                }
                .font(DS.Typography.subheadline)
                .foregroundStyle(DS.Colors.accent)

                DSDivider("or")

                // Apple Sign In Button
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.email, .fullName]
                } onCompletion: { result in
                    state.auth.handleAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))

                // Create account link
                HStack(spacing: DS.Spacing.xs) {
                    Text("Don't have an account?")
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)

                    Button("Create Account") {
                        router.present(.register)
                    }
                    .font(DS.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(DS.Colors.accent)
                }
                .padding(.top, DS.Spacing.md)

                Spacer(minLength: DS.Spacing.xxxl)
            }
            .padding(.horizontal, DS.Spacing.xl)
        }
        .floatingErrorBanner($state.auth.error) {
            await state.auth.signIn(email: email, password: password)
        }
        .surfaceBackground()
    }
}
