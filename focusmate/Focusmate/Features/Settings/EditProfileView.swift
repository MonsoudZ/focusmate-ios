import SwiftUI

struct EditProfileView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var appState: AppState

  @State private var viewModel: EditProfileViewModel

  init(user: UserDTO, apiClient: APIClient) {
    _viewModel = State(initialValue: EditProfileViewModel(user: user, apiClient: apiClient))
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Profile Information") {
          HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "person.fill")
              .foregroundStyle(DS.Colors.accent)
              .frame(width: 24)
            TextField("Your name", text: self.$viewModel.name)
              .font(DS.Typography.body)
              .textContentType(.name)
              .textInputAutocapitalization(.words)
          }
        }
      }
      .surfaceFormBackground()
      .navigationTitle("Edit Profile")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            self.dismiss()
          }
          .buttonStyle(IntentiaToolbarCancelStyle())
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            Task {
              if let updatedUser = await viewModel.updateProfile() {
                self.appState.auth.currentUser = updatedUser
                // Brief delay to allow UI state to propagate before dismissing
                do {
                  try await Task.sleep(nanoseconds: 100_000_000)
                } catch {
                  // Task cancelled, still dismiss
                }
                self.dismiss()
              }
            }
          }
          .buttonStyle(IntentiaToolbarPrimaryStyle())
          .disabled(self.viewModel.isLoading || self.viewModel.name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
      }
      .overlay {
        if self.viewModel.isLoading {
          ProgressView()
            .scaleEffect(1.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.2))
        }
      }
      .floatingErrorBanner(self.$viewModel.error)
    }
  }
}

struct UpdateProfileRequest: Encodable {
  let name: String
  let timezone: String
}

struct UserResponse: Codable {
  let user: UserDTO
}
