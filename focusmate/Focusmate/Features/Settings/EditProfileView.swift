import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    @State private var name: String
    @State private var timezone: String
    @State private var isLoading = false
    @State private var error: FocusmateError?

    private let timezones = TimeZone.knownTimeZoneIdentifiers.sorted()

    init(user: UserDTO) {
        _name = State(initialValue: user.name ?? "")
        _timezone = State(initialValue: user.timezone ?? TimeZone.current.identifier)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile Information") {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)

                    Picker("Timezone", selection: $timezone) {
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
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveProfile() }
                    }
                    .disabled(isLoading || name.trimmingCharacters(in: .whitespaces).isEmpty)
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
            .errorBanner($error)
        }
    }

    private func saveProfile() async {
        isLoading = true
        error = nil

        do {
            let response: UserResponse = try await appState.auth.api.request(
                "PATCH",
                API.Users.profile,
                body: UpdateProfileRequest(name: name, timezone: timezone)
            )

            await MainActor.run {
                appState.auth.currentUser = response.user
            }
            
            try? await Task.sleep(nanoseconds: 100_000_000)
            
            dismiss()
        } catch let err as FocusmateError {
            error = err
        } catch {
            self.error = .custom("PROFILE_ERROR", error.localizedDescription)
        }

        isLoading = false
    }
}

struct UpdateProfileRequest: Encodable {
    let name: String
    let timezone: String
}

struct UserResponse: Codable {
    let user: UserDTO
}
