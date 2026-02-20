import SwiftUI

struct DeleteAccountView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(AppState.self) var appState

  @State private var viewModel: DeleteAccountViewModel

  init(apiClient: APIClient, authStore: AuthStore) {
    _viewModel = State(initialValue: DeleteAccountViewModel(apiClient: apiClient, authStore: authStore))
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Text(
            "This action cannot be undone. All your data, including lists, tasks, and settings will be permanently deleted."
          )
          .foregroundColor(.secondary)
        }

        if !self.viewModel.isAppleUser {
          Section {
            SecureField("Enter your password", text: self.$viewModel.password)
              .textContentType(.password)
          } header: {
            Text("Verify Your Identity")
          }
        }

        Section {
          TextField("Type \(self.viewModel.requiredConfirmText) to confirm", text: self.$viewModel.confirmText)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
        } header: {
          Text("Confirm Deletion")
        } footer: {
          Text("Type \(self.viewModel.requiredConfirmText) to confirm you want to delete your account.")
        }

        Section {
          Button(role: .destructive) {
            self.viewModel.showFinalConfirmation = true
          } label: {
            HStack {
              Spacer()
              if self.viewModel.isLoading {
                ProgressView()
              } else {
                Text("Delete My Account")
              }
              Spacer()
            }
          }
          .disabled(!self.viewModel.canDelete || self.viewModel.isLoading)
        }
      }
      .surfaceFormBackground()
      .navigationTitle("Delete Account")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            self.dismiss()
          }
          .buttonStyle(IntentiaToolbarCancelStyle())
        }
      }
      .floatingErrorBanner(self.$viewModel.error)
      .alert("Are you absolutely sure?", isPresented: self.$viewModel.showFinalConfirmation) {
        Button("Cancel", role: .cancel) {}
        Button("Delete Forever", role: .destructive) {
          Task { await self.viewModel.deleteAccount() }
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
