import SwiftUI

struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    @State private var viewModel: DeleteAccountViewModel

    init(apiClient: APIClient, authStore: AuthStore) {
        _viewModel = State(initialValue: DeleteAccountViewModel(apiClient: apiClient, authStore: authStore))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This action cannot be undone. All your data, including lists, tasks, and settings will be permanently deleted.")
                        .foregroundColor(.secondary)
                }

                if !viewModel.isAppleUser {
                    Section {
                        SecureField("Enter your password", text: $viewModel.password)
                            .textContentType(.password)
                    } header: {
                        Text("Verify Your Identity")
                    }
                }

                Section {
                    TextField("Type \(viewModel.requiredConfirmText) to confirm", text: $viewModel.confirmText)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                } header: {
                    Text("Confirm Deletion")
                } footer: {
                    Text("Type \(viewModel.requiredConfirmText) to confirm you want to delete your account.")
                }

                Section {
                    Button(role: .destructive) {
                        viewModel.showFinalConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                            } else {
                                Text("Delete My Account")
                            }
                            Spacer()
                        }
                    }
                    .disabled(!viewModel.canDelete || viewModel.isLoading)
                }
            }
            .surfaceFormBackground()
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(IntentiaToolbarCancelStyle())
                }
            }
            .floatingErrorBanner($viewModel.error)
            .alert("Are you absolutely sure?", isPresented: $viewModel.showFinalConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Forever", role: .destructive) {
                    Task { await viewModel.deleteAccount() }
                }
            } message: {
                Text("This will permanently delete your account and all associated data. This cannot be undone.")
            }
        }
    }
}

struct DeleteAccountRequest: Encodable {
    let password: String?
}
