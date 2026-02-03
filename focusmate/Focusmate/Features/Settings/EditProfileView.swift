import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    @State private var viewModel: EditProfileViewModel

    private let timezones = TimeZone.knownTimeZoneIdentifiers.sorted()

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
                        TextField("Your name", text: $viewModel.name)
                            .font(DS.Typography.body)
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                    }

                    Picker("Timezone", selection: $viewModel.timezone) {
                        ForEach(timezones, id: \.self) { tz in
                            Text(tz).tag(tz)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
            }
            .surfaceFormBackground()
            .navigationTitle("Edit Profile")
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
                        Task {
                            if let updatedUser = await viewModel.updateProfile() {
                                appState.auth.currentUser = updatedUser
                                try? await Task.sleep(nanoseconds: 100_000_000)
                                dismiss()
                            }
                        }
                    }
                    .buttonStyle(IntentiaToolbarPrimaryStyle())
                    .disabled(viewModel.isLoading || viewModel.name.trimmingCharacters(in: .whitespaces).isEmpty)
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
            .floatingErrorBanner($viewModel.error)
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
