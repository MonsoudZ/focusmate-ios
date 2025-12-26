import SwiftUI

struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    
    @State private var password = ""
    @State private var confirmText = ""
    @State private var isLoading = false
    @State private var error: FocusmateError?
    @State private var showFinalConfirmation = false
    
    private let requiredConfirmText = "DELETE"
    
    private var isAppleUser: Bool {
        appState.auth.currentUser?.hasPassword == false
    }
    
    private var canDelete: Bool {
        confirmText == requiredConfirmText &&
        (isAppleUser || !password.isEmpty)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This action cannot be undone. All your data, including lists, tasks, and settings will be permanently deleted.")
                        .foregroundColor(.secondary)
                }
                
                if !isAppleUser {
                    Section {
                        SecureField("Enter your password", text: $password)
                            .textContentType(.password)
                    } header: {
                        Text("Verify Your Identity")
                    }
                }
                
                Section {
                    TextField("Type \(requiredConfirmText) to confirm", text: $confirmText)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                } header: {
                    Text("Confirm Deletion")
                } footer: {
                    Text("Type \(requiredConfirmText) to confirm you want to delete your account.")
                }
                
                Section {
                    Button(role: .destructive) {
                        showFinalConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("Delete My Account")
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canDelete || isLoading)
                }
            }
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .errorBanner($error)
            .alert("Are you absolutely sure?", isPresented: $showFinalConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Forever", role: .destructive) {
                    Task { await deleteAccount() }
                }
            } message: {
                Text("This will permanently delete your account and all associated data. This cannot be undone.")
            }
        }
    }
    
    private func deleteAccount() async {
        isLoading = true
        error = nil
        
        do {
            let _: EmptyResponse = try await appState.auth.api.request(
                "DELETE",
                API.Users.profile,
                body: DeleteAccountRequest(password: isAppleUser ? nil : password)
            )
            
            await appState.auth.signOut()
        } catch let err as FocusmateError {
            error = err
        } catch {
            self.error = ErrorHandler.shared.handle(error)
        }
        
        isLoading = false
    }
}

struct DeleteAccountRequest: Encodable {
    let password: String?
}
