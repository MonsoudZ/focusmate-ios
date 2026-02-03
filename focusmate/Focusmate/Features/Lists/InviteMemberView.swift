import SwiftUI

struct InviteMemberView: View {
    let onInvited: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: InviteMemberViewModel

    init(list: ListDTO, apiClient: APIClient, onInvited: @escaping () -> Void) {
        self.onInvited = onInvited
        _viewModel = State(initialValue: InviteMemberViewModel(list: list, apiClient: apiClient))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email address", text: $viewModel.email)
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
                    Picker("Role", selection: $viewModel.role) {
                        Text("Editor").tag("editor")
                        Text("Viewer").tag("viewer")
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Permission")
                } footer: {
                    Text(viewModel.role == "editor"
                         ? "Editors can add, edit, and complete tasks."
                         : "Viewers can only see tasks.")
                }
            }
            .surfaceFormBackground()
            .navigationTitle("Invite Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Invite") {
                        Task {
                            if await viewModel.invite() {
                                onInvited()
                                dismiss()
                            }
                        }
                    }
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
            .floatingErrorBanner($viewModel.error)
        }
    }
}
