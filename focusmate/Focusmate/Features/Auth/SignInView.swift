import SwiftUI

struct SignInView: View {
    @EnvironmentObject var state: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var showingRegister = false
    var body: some View {
        VStack(spacing: 16) {
            Text("Focusmate").font(.largeTitle.bold())
            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundColor(.black)
                .accentColor(.black)
                .textFieldStyle(.roundedBorder)
            SecureField("Password", text: $password)
                .foregroundColor(.black)
                .accentColor(.black)
                .textFieldStyle(.roundedBorder)
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
                Text("Sign Up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(state.auth.isLoading)
            
            if let err = state.auth.error { Text(err).foregroundColor(.red).font(.footnote) }
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingRegister) {
            RegisterView()
        }
    }
}


