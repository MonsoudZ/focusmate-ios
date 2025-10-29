import SwiftUI

struct SignInView: View {
  @EnvironmentObject var state: AppState
  @State private var email = ""
  @State private var password = ""
  @State private var showingRegister = false
  var body: some View {
    VStack(spacing: 16) {
      Text("Focusmate").font(.largeTitle.bold())
      TextField("Email", text: self.$email)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .foregroundColor(.black)
        .accentColor(.black)
        .textFieldStyle(.roundedBorder)
      SecureField("Password", text: self.$password)
        .foregroundColor(.black)
        .accentColor(.black)
        .textFieldStyle(.roundedBorder)
      Button {
        Task { await self.state.auth.signIn(email: self.email, password: self.password) }
      } label: {
        Text(self.state.auth.isLoading ? "Signing in…" : "Sign In")
          .frame(maxWidth: .infinity)
          .foregroundColor(.white)
      }
      .buttonStyle(.borderedProminent)
      .disabled(self.state.auth.isLoading || self.email.isEmpty || self.password.isEmpty)

      Button {
        self.showingRegister = true
      } label: {
        Text("Sign Up")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .disabled(self.state.auth.isLoading)

      if let err = state.auth.error { Text(err).foregroundColor(.red).font(.footnote) }
      Spacer()
    }
    .padding()
    .sheet(isPresented: self.$showingRegister) {
      RegisterView()
    }
  }
}
