import SwiftUI

struct CreateTagView: View {
    let tagService: TagService
    var onCreated: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var selectedColor: String = "blue"
    @State private var isLoading = false
    @State private var error: FocusmateError?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Tag Name") {
                    TextField("Name", text: $name)
                }
                
                Section("Color") {
                    ListColorPicker(selected: $selectedColor)
                        .padding(.vertical, DS.Spacing.sm)
                }
                
                Section("Preview") {
                    HStack {
                        Circle()
                            .fill(DS.Colors.list(selectedColor))
                            .frame(width: 8, height: 8)
                        Text(name.isEmpty ? "Tag Name" : name)
                            .font(.caption)
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.list(selectedColor).opacity(0.2))
                    .clipShape(Capsule())
                }
            }
            .surfaceFormBackground()
            .navigationTitle("New Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(IntentiaToolbarCancelStyle())
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create Tag") {
                        Task { await createTag() }
                    }
                    .buttonStyle(IntentiaToolbarPrimaryStyle())
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
            }
            .errorBanner($error)
        }
    }
    
    private func createTag() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            _ = try await tagService.createTag(name: trimmedName, color: selectedColor)
            HapticManager.success()
            onCreated?()
            dismiss()
        } catch let err as FocusmateError {
            error = err
            HapticManager.error()
        } catch {
            self.error = .custom("CREATE_TAG_ERROR", error.localizedDescription)
            HapticManager.error()
        }
    }
}
