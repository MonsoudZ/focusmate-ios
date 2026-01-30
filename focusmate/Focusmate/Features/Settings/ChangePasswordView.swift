import SwiftUI

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ChangePasswordViewModel

    init(apiClient: APIClient) {
        _viewModel = State(initialValue: ChangePasswordViewModel(apiClient: apiClient))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Current Password", text: $viewModel.currentPassword)
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
                    SecureField("New Password", text: $viewModel.newPassword)
                        .textContentType(.newPassword)

                    SecureField("Confirm New Password", text: $viewModel.confirmPassword)
                        .textContentType(.newPassword)
                } footer: {
                    if viewModel.newPassword.count > 0 && viewModel.newPassword.count < 8 {
                        Text("Password must be at least 8 characters.")
                            .foregroundColor(.red)
                    } else if !viewModel.confirmPassword.isEmpty && viewModel.newPassword != viewModel.confirmPassword {
                        Text("Passwords don't match.")
                            .foregroundColor(.red)
                    }
                }
            }
            .surfaceFormBackground()
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(IntentiaToolbarCancelStyle())
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await viewModel.changePassword() }
                    }
                    .buttonStyle(IntentiaToolbarPrimaryStyle())
                    .disabled(!viewModel.isValid || viewModel.isLoading)
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
            .errorBanner($viewModel.error)
            .alert("Success", isPresented: $viewModel.showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your password has been changed.")
            }
        }
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
