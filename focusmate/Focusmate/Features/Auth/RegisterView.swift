import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Create Account").font(.largeTitle.bold())
            
            TextField("Name", text: $name)
                .textInputAutocapitalization(.words)
                .foregroundColor(.black)
                .accentColor(.black)
                .textFieldStyle(.roundedBorder)
            
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
            
            SecureField("Confirm Password", text: $confirmPassword)
                .foregroundColor(.black)
                .accentColor(.black)
                .textFieldStyle(.roundedBorder)
            
            Button {
                Task { await register() }
            } label: { 
                Text(state.auth.isLoading ? "Creating Account…" : "Create Account")
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
            }
            .buttonStyle(.borderedProminent)
            .disabled(state.auth.isLoading || email.isEmpty || password.isEmpty || name.isEmpty || password != confirmPassword)
            
            Button {
                // Navigate back to sign in
                state.auth.jwt = nil
                state.auth.currentUser = nil
            } label: { 
                Text("Back to Sign In")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(state.auth.isLoading)
            
            if let err = state.auth.error { 
                Text(err).foregroundColor(.red).font(.footnote) 
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func register() async {
        print("🔄 RegisterView: Starting registration...")
        // Clear any previous errors before starting registration
        state.auth.error = nil
        await state.auth.register(email: email, password: password, name: name)
        
        // If registration was successful, dismiss the modal
        if state.auth.jwt != nil && state.auth.currentUser != nil {
            print("✅ RegisterView: Registration successful, dismissing modal...")
            await MainActor.run {
                dismiss()
            }
        }
    }
}