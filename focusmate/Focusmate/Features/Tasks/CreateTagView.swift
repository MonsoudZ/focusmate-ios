import SwiftUI

struct CreateTagView: View {
  let tagService: TagService
  var onCreated: ((TagDTO) -> Void)?
  @Environment(\.dismiss) var dismiss
  @FocusState private var isNameFocused: Bool

  @State private var name = ""
  @State private var selectedColor: String = "blue"
  @State private var isLoading = false
  @State private var error: FocusmateError?

  var body: some View {
    NavigationStack {
      Form {
        Section("Tag Name") {
          HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "tag.fill")
              .foregroundStyle(DS.Colors.list(self.selectedColor))
              .frame(width: 24)
            TextField("Enter tag name", text: self.$name)
              .font(DS.Typography.body)
              .focused(self.$isNameFocused)
          }
        }

        Section("Color") {
          ListColorPicker(selected: self.$selectedColor)
            .padding(.vertical, DS.Spacing.sm)
        }

        Section("Preview") {
          HStack {
            Circle()
              .fill(DS.Colors.list(self.selectedColor))
              .frame(width: 8, height: 8)
            Text(self.name.isEmpty ? "Tag Name" : self.name)
              .font(.caption)
          }
          .padding(.horizontal, DS.Spacing.md)
          .padding(.vertical, DS.Spacing.sm)
          .background(DS.Colors.list(self.selectedColor).opacity(DS.Opacity.tintBackgroundActive))
          .clipShape(Capsule())
        }
      }
      .surfaceFormBackground()
      .navigationTitle("New Tag")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            self.dismiss()
          }
          .buttonStyle(IntentiaToolbarCancelStyle())
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("Create Tag") {
            Task { await self.createTag() }
          }
          .buttonStyle(IntentiaToolbarPrimaryStyle())
          .disabled(self.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || self.isLoading)
        }
      }
      .floatingErrorBanner(self.$error)
      .task {
        try? await Task.sleep(for: .seconds(0.5))
        self.isNameFocused = true
      }
    }
  }

  private func createTag() async {
    let trimmedName = self.name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else { return }

    self.isLoading = true
    defer { isLoading = false }

    do {
      let newTag = try await tagService.createTag(name: trimmedName, color: self.selectedColor)
      HapticManager.success()
      self.onCreated?(newTag)
      self.dismiss()
    } catch let err as FocusmateError {
      error = err
      HapticManager.error()
    } catch {
      self.error = .custom("CREATE_TAG_ERROR", error.localizedDescription)
      HapticManager.error()
    }
  }
}
