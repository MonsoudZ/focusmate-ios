import SwiftUI

struct InviteMemberView: View {
    let list: ListDTO
    let apiClient: APIClient
    let onInvited: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var role = "editor"
    @State private var isLoading = false
    @State private var error: FocusmateError?
    
    private var isValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        email.contains("@")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email address", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Invite by Email")
                } footer: {
                    Text("Enter the email address of the person you want to invite.")
                }
                
                Section {
                    Picker("Role", selection: $role) {
                        Text("Editor").tag("editor")
                        Text("Viewer").tag("viewer")
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Permission")
                } footer: {
                    Text(role == "editor"
                         ? "Editors can add, edit, and complete tasks."
                         : "Viewers can only see tasks.")
                }
            }
            .navigationTitle("Invite Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Invite") {
                        Task { await inviteMember() }
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
            .errorBanner($error)
        }
    }
    
    private func inviteMember() async {
        isLoading = true
        error = nil
        
        do {
            let _: MembershipResponse = try await apiClient.request(
                "POST",
                API.Lists.memberships(String(list.id)),
                body: CreateMembershipRequest(
                    membership: MembershipParams(
                        user_identifier: email.trimmingCharacters(in: .whitespaces).lowercased(),
                        role: role
                    )
                )
            )
            onInvited()
            dismiss()
        } catch let err as FocusmateError {
            error = err
        } catch {
            self.error = ErrorHandler.shared.handle(error)
        }
        
        isLoading = false
    }
}
