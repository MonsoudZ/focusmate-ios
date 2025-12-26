import SwiftUI

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var showSuccess = false
    
    private var isValid: Bool {
        !currentPassword.isEmpty &&
        newPassword.count >= 6 &&
        newPassword == confirmPassword
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Current Password", text: $currentPassword)
                        .textContentType(.password)
                } footer: {
                    HStack {
                        Text("Enter your current password to verify your identity.")
                        Spacer()
                        Button("Forgot?") {
                            if let url = URL(string: "https://intentia.app/reset-password") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.subheadline)
                    }
                }
                
                Section {
                    SecureField("New Password", text: $newPassword)
                        .textContentType(.newPassword)
                    
                    SecureField("Confirm New Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                } footer: {
                    if newPassword.count > 0 && newPassword.count < 6 {
                        Text("Password must be at least 6 characters.")
                            .foregroundColor(.red)
                    } else if !confirmPassword.isEmpty && newPassword != confirmPassword {
                        Text("Passwords don't match.")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await changePassword() }
                    }
                    .disabled(!isValid || isLoading)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
            .alert("Error", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                if let error {
                    Text(error)
                }
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your password has been changed.")
            }
        }
    }
    
    private func changePassword() async {
        isLoading = true
        error = nil
        
        do {
            let _: EmptyResponse = try await appState.auth.api.request(
                "PUT",
                API.Users.password,
                body: ChangePasswordRequest(
                    currentPassword: currentPassword,
                    password: newPassword,
                    passwordConfirmation: confirmPassword
                )
            )
            showSuccess = true
        } catch let err as FocusmateError {
            error = err.message
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
}

struct ChangePasswordRequest: Encodable {
    let currentPassword: String
    let password: String
    let passwordConfirmation: String
    
    enum CodingKeys: String, CodingKey {
        case currentPassword = "current_password"
        case password
        case passwordConfirmation = "password_confirmation"
    }
}

