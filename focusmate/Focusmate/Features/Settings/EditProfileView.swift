import SwiftUI

struct EditProfileView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var appState: AppState

  @State private var name: String
  @State private var timezone: String
  @State private var isLoading = false
  @State private var error: String?
  @State private var showSuccessMessage = false

  private let timezones = TimeZone.knownTimeZoneIdentifiers.sorted()

  init(user: UserDTO) {
    _name = State(initialValue: user.name)
    _timezone = State(initialValue: user.timezone ?? TimeZone.current.identifier)
  }

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Profile Information")) {
          TextField("Name", text: $name)
            .textContentType(.name)
            .autocapitalization(.words)

          Picker("Timezone", selection: $timezone) {
            ForEach(timezones, id: \.self) { tz in
              Text(tz).tag(tz)
            }
          }
          .pickerStyle(.navigationLink)
        }

        if let errorMessage = error {
          Section {
            HStack {
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
              Text(errorMessage)
                .font(.caption)
                .foregroundColor(.red)
            }
          }
        }

        if showSuccessMessage {
          Section {
            Label("Profile updated successfully", systemImage: "checkmark.circle.fill")
              .foregroundColor(.green)
          }
        }
      }
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
            Task {
              await saveProfile()
            }
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
    }
  }

  private func saveProfile() async {
    isLoading = true
    error = nil
    showSuccessMessage = false

    do {
      let updatedUser: UserDTO = try await appState.auth.api.request(
        "PATCH",
        "profile",
        body: UpdateProfileRequest(name: name, timezone: timezone)
      )

      // Update the current user in app state
      await MainActor.run {
        appState.auth.currentUser = updatedUser
        showSuccessMessage = true
      }

      // Auto-dismiss after success
      try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
      await MainActor.run {
        dismiss()
      }

      Logger.info("Profile updated successfully", category: .auth)
    } catch {
      await MainActor.run {
        self.error = "Failed to update profile: \(error.localizedDescription)"
      }
      Logger.error("Profile update failed", error: error, category: .auth)
    }

    isLoading = false
  }
}

// MARK: - Request Model

struct UpdateProfileRequest: Encodable {
  let name: String
  let timezone: String
}

#Preview {
  EditProfileView(user: UserDTO(
    id: 1,
    email: "test@example.com",
    name: "Test User",
    role: "user",
    timezone: "America/New_York"
  ))
  .environmentObject(AppState())
}
