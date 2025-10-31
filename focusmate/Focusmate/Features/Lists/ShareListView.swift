import SwiftUI

struct ShareListView: View {
  let list: ListDTO
  let listService: ListService

  @Environment(\.dismiss) private var dismiss
  @State private var email = ""
  @State private var selectedRole = "viewer"
  @State private var isLoading = false
  @State private var error: FocusmateError?
  @State private var shares: [ListShare] = []

  private let roles = [
    ("viewer", "Viewer", "Can view tasks only"),
    ("editor", "Editor", "Can view and edit tasks"),
    ("admin", "Admin", "Full access including sharing"),
  ]

  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        // Header
        VStack(alignment: .leading, spacing: 8) {
          Text("Share '\(self.list.title)'")
            .font(.title2)
            .fontWeight(.bold)

          Text("Invite others to collaborate on this list")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        // Current Shares
        if !self.shares.isEmpty {
          VStack(alignment: .leading, spacing: 12) {
            Text("Currently Shared With")
              .font(.headline)

            ForEach(self.shares) { share in
              HStack {
                VStack(alignment: .leading, spacing: 4) {
                  Text(share.user?.name ?? "Unknown User")
                    .font(.subheadline)
                    .fontWeight(.medium)

                  Text(share.user?.email ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                Text(share.roleDisplayName)
                  .font(.caption)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(share.roleColor.opacity(0.2))
                  .foregroundColor(share.roleColor)
                  .clipShape(Capsule())
              }
              .padding(.vertical, 4)
            }
          }
          .padding()
          .background(Color(.systemGray6))
          .clipShape(RoundedRectangle(cornerRadius: 12))
        }

        // Invite Form
        VStack(spacing: 16) {
          VStack(alignment: .leading, spacing: 8) {
            Text("Invite New User")
              .font(.headline)

            TextField("Email address", text: self.$email)
              .textFieldStyle(.roundedBorder)
              .keyboardType(.emailAddress)
              .autocapitalization(.none)
              .disableAutocorrection(true)
          }

          VStack(alignment: .leading, spacing: 8) {
            Text("Role")
              .font(.headline)

            ForEach(self.roles, id: \.0) { role in
              HStack {
                Button {
                  self.selectedRole = role.0
                } label: {
                  HStack {
                    Image(systemName: self.selectedRole == role.0 ? "checkmark.circle.fill" : "circle")
                      .foregroundColor(self.selectedRole == role.0 ? .blue : .gray)

                    VStack(alignment: .leading, spacing: 2) {
                      Text(role.1)
                        .font(.subheadline)
                        .fontWeight(.medium)

                      Text(role.2)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    Spacer()
                  }
                }
                .buttonStyle(.plain)
              }
              .padding(.vertical, 4)
            }
          }

          Button {
            Task {
              await self.shareList()
            }
          } label: {
            HStack {
              if self.isLoading {
                ProgressView()
                  .scaleEffect(0.8)
              } else {
                Image(systemName: "paperplane")
              }
              Text("Send Invite")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(self.email.isEmpty ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
          }
          .disabled(self.email.isEmpty || self.isLoading)
        }

        Spacer()
      }
      .padding()
      .navigationTitle("Share List")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            self.dismiss()
          }
        }
      }
      .task {
        await self.loadShares()
      }
      .alert("Error", isPresented: .constant(self.error != nil)) {
        Button("OK") {
          self.error = nil
        }
      } message: {
        if let error {
          Text(error.errorDescription ?? "An error occurred")
        }
      }
    }
  }

  private func shareList() async {
    guard !self.email.isEmpty else { return }

    self.isLoading = true
    self.error = nil

    do {
      let request = ShareListRequest(email: email, role: selectedRole)
      let response: ShareListResponse = try await listService.shareList(id: self.list.id, request: request)

      // Convert ShareListResponse to ListShare for display
      let newShare = ListShare(
        id: response.id,
        list_id: response.list_id,
        user_id: response.user?.id ?? 0,
        role: response.role,
        created_at: response.created_at,
        updated_at: response.updated_at,
        user: response.user
      )

      // Add the new share to the list
      self.shares.append(newShare)

      // Clear the form
      self.email = ""
      self.selectedRole = "viewer"

      print("✅ ShareListView: Successfully shared list with \(response.email)")
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      print("❌ ShareListView: Failed to share list: \(error)")
    }

    self.isLoading = false
  }

  private func loadShares() async {
    do {
      self.shares = try await self.listService.fetchShares(listId: self.list.id)
      print("✅ ShareListView: Loaded \(self.shares.count) shares")
    } catch {
      print("❌ ShareListView: Failed to load shares: \(error)")
    }
  }
}
